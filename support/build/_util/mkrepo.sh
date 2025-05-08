#!/usr/bin/env bash

# fail hard
set -o pipefail
# fail harder
set -eu

help=false
checksum=
upload=false

S5CMD_OPTIONS=(${S5CMD_NO_SIGN_REQUEST:+--no-sign-request} ${S5CMD_PROFILE:+--profile "${S5CMD_PROFILE}"} --log error)

# process flags
optstring=":-:hc:"
while getopts "$optstring" opt; do
	case $opt in
		h)
			help=true
			;;
		c)
			checksum=$OPTARG
			;;
		-)
			case "$OPTARG" in
				help)
					help=true
					;;
				upload)
					upload=true
					;;
				*)
					echo "Invalid option: --$OPTARG" >&2
					exit 2
					;;
			esac
	esac
done
# clear processed arguments
shift $((OPTIND-1))

if $help; then
	cat >&2 <<-EOF
		Usage: $(basename "$0") [-c CHECKSUM] [--upload] [MANIFEST...]
		  The environment variables '\$S3_BUCKET', '\$S3_PREFIX', and '\$S3_REGION' are
		  used for S3 bucket addressing; the prefix is optional, and the region is auto-
		  detected if not given.
		  
		  If MANIFEST arguments are given, those are used to build the repo; otherwise,
		  all manifests from S3_BUCKET+S3_PREFIX are downloaded.
		  
		  The -c option, if given, causes uploading or writing (see --upload below)
		  of an additional packages.CHECKSUM.json as a snapshot.
		  
		  A --upload flag triggers immediate upload, otherwise instructions are printed.
		  
		  If --upload, or if stdout is a terminal, packages.json will be written to cwd.
		  If no --upload, and if stdout is a pipe, repo JSON will be echo'd to stdout.
	EOF
	exit 2
fi

S3_PREFIX=${S3_PREFIX:-}

# grep out the region (it's there even on 403 responses), and trim whitespace via xargs - important to use grep -o and discard trailing whitespace, otherwise we'll end up with a carriage return at the end of the value
S3_REGION=${S3_REGION:-$(set -o pipefail; curl -sI "https://${S3_BUCKET}.s3.amazonaws.com/" | grep -E -o -i "^x-amz-bucket-region:\s*\S+" | cut -d: -f2 | xargs || { echo >&2 "Failed to determine region for S3 bucket '$S3_BUCKET'"; exit 1; })}

if [[ $# == "0" ]]; then
	manifests_tmp=$(mktemp -d -t "dst-repo.XXXXX")
	trap 'rm -rf "$manifests_tmp";' EXIT
	echo "-----> Fetching manifests... " >&2
	(
		cd "$manifests_tmp"
		s5cmd "${S5CMD_OPTIONS[@]}" cp --source-region "$S3_REGION" "s3://${S3_BUCKET}/${S3_PREFIX}*.composer.json" . || { echo -e "\nFailed to fetch manifests! See message above for errors." >&2; exit 1; }
	)
	manifests=("$manifests_tmp"/*.composer.json)
else
	manifests=("$@")
fi

echo "-----> Generating packages.json..." >&2
redir=false
if $upload || [[ -t 1 ]]; then
	redir=true
	# if stdout is a terminal or if we're uploading; we write a "packages.json" instead of echoing
	# this is so other programs can pipe our output and capture the generated repo from stdout
	# also back up stdout so we restore it to the right thing (tty or pipe) later
	exec 3>&1 1>packages.json
fi

# load and filter all the given manifests in two steps: 1) expand shared PHP extensions; 2) sort
# expand shared PHP extensions by creating a dummy package for every extension (in every PHP package) that is built as shared, so the solver can correctly pick it for installation
# sort so that packages with the same name and version (e.g. ext-memcached 2.2.0) show up with their php requirement in descending order - otherwise a Composer limitation means that a simple "ext-memcached: * + php: ^7.0.0" request would install 7.0.latest and not 7.4.latest, as it finds the 7.0.* requirement extension first and sticks to that instead of 7.4. For packages with identical names and versions (but different e.g. requirements), Composer basically treats them as equal and picks as a winner whatever it finds first. The requirements have to be written like "x.y.*" for this to work of course (we replace "*", "<=" and so forth with "0", as that's fine for the purpose of just sorting - otherwise, a comparison of e.g. "^7.0.0" and "7.0.*" would cause "TypeError: '<' not supported between instances of 'str' and 'int'")
python <(cat <<-'PYTHON' # beware of single quotes in body
	import sys, re, json
	from itertools import groupby
	from natsort import natsorted
	from operator import itemgetter
	manifests = [ json.load(open(item)) for item in sys.argv[1:] if json.load(open(item)).get("type", "") != "heroku-sys-package" ]
	# first, we need to discard packages with the same name and version, but different build infos in the version string
	# only the natsorted-ly "highest" variant remains
	# this is to ensure that we do not end up with "foo-1.0.1" and "foo-1.0.1+build2" in the repo, because semver considers these equivalent, and so does Composer
	# we only want "foo-1.0.1+build2" in this case, as it'll be the newer/higher package
	rsorted = natsorted(manifests, lambda p: (p["name"], p["version"]), reverse=True) # reverse natsort by name and entire version
	version_groups = groupby(rsorted, lambda p: (p["name"], p["version"].partition("+")[0])) # group by only the version part before a possible "+"
	version_whitelist = set(itemgetter("name", "version")(next(paks)) for group, paks in version_groups) # make a set of whitelisted name/version combos
	manifests = [m for m in manifests if (m["name"], m["version"]) in version_whitelist] # remove any manifest with versions not in whitelist
	# for PHP, transform all manifests in extra.shared into their own packages
	for php in filter(lambda package: package.get("type", "") == "heroku-sys-php", manifests):
	    shared = php.get("extra", {}).get("shared", {})
	    for extname in shared.keys():
	        if shared[extname] is True:
	            continue # an older php package manifest that only has a list of shared extensions (name as key, true as value) rather than the versions as well, and lists even shared extensions in "replace"; this means we don't want to give it this treatment below
	        shared[extname]["dist"]["url"] = "{}?extension={}".format(php.get("dist").get("url"), extname) # make sure "virtual" URL in the shared ext info has the right "base" (e.g. after a sync from another bucket)
	        manifests.append(shared[extname]); # add ext manifest to our repo list
	        shared[extname] = False # make sure there still is a record of this extension in the PHP package (e.g. for tooling that generates version infos for Heroku Dev Center), but prevent e.g. the legacy Installer Plugin logic from handling this
	# for each php or extension package, generate a "replace" entry for ".native", and require ".native" variants of any other exts it depends on
	# this is used by the installer to ignore userland provides for internal dependencies (one ext requiring another), while allowing userland provides to optionally stand in for native extensions if they do not exist (but an installation attempt is made for them once main dependency resolution is finished)
	# this way, extension package formulae do not have to know about this ".native" business in their formulae
	for pkg in filter(lambda package: package.get("type", "") in ["heroku-sys-php", "heroku-sys-php-extension"], manifests):
	    # generate ".native" replace and require entry variants for each "heroku-sys/ext-…" in them
	    # there may be extensions "replace"ing other extensions, e.g. "ext-apcu" replaces "ext-apc"
	    # also, all non-shared extensions are listed as "replace"d by a PHP package
	    replaces = pkg.setdefault("replace", {}) # setdefault because we likely also need to insert a new item later
	    requires = pkg.get("require", {})
	    # we only process requirements not ending with ".native" (in case an extension package already explicitly does this in its metadata)
	    replaces.update({ "%s.native"%name: version for (name, version) in replaces.items() if name.startswith("heroku-sys/ext-") and not name.endswith(".native")})
	    requires.update({ "%s.native"%name: version for (name, version) in requires.items() if name.startswith("heroku-sys/ext-") and not name.endswith(".native")})
	    # finally, for this package itself, insert a replace entry of "heroku-sys/ext-thispackage.native" if it's an extension
	    if pkg.get("type") == "heroku-sys-php-extension":
	        replaces["%s.native"%pkg.get("name", "")] = "self.version"
	# we sort by a tuple: name first (so the following dictionary grouping works), then "php" requirement (see initial comment block)
	manifests = natsorted(manifests,
	    key=lambda package: (package.get("name"), re.sub(r"[<>=*~^]", "0", package.get("require", {}).get("heroku-sys/php", "0.0.0"))),
	    reverse=True)
	# convert the list to a dict with package names as keys and list of versions (sorted by "php" requirement by previous sort) as values
	json.dump({"packages": dict((name, list(versions)) for name, versions in groupby(manifests, key=lambda package: package.get("name"))) }, sys.stdout, sort_keys=True)
PYTHON
) "${manifests[@]}"

# restore stdout
# note that 'exec >$(tty)' does not work as FD 1 may have been a pipe originally and not a tty
if $redir; then
	exec 1>&3 3>&-
fi

packages_json_upload_cmd=(s5cmd "${S5CMD_OPTIONS[@]}" cp --destination-region "$S3_REGION" --content-type application/json packages.json "s3://${S3_BUCKET}/${S3_PREFIX}packages.json")
if [[ -n "$checksum" ]]; then
	# cp s3://.../packages.json s3://...packages-${checksum}.json
	packages_snapshot_json_cp_cmd=(s5cmd "${S5CMD_OPTIONS[@]}" cp --source-region "$S3_REGION" --destination-region "$S3_REGION" "s3://${S3_BUCKET}/${S3_PREFIX}packages"{,"-${checksum}"}".json")
fi
if $upload; then
	echo "-----> Uploading packages.json..." >&2
	"${packages_json_upload_cmd[@]}" 1>&2
	if [[ -n "$checksum" ]]; then
		echo "-----> Snapshotting to packages-${checksum}.json..." >&2
		"${packages_snapshot_json_cp_cmd[@]}" 1>&2
	fi
	echo "-----> Done." >&2
elif [[ -t 1 ]]; then
	echo "-----> Done. To upload repository, run:" >&2
	echo "${packages_json_upload_cmd[@]@Q}" >&2
	if [[ -n "$checksum" ]]; then
		echo "       and (for repository snapshot)": >&2
		echo "${packages_snapshot_json_cp_cmd[@]@Q}" >&2
	fi
fi
