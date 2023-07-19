#!/usr/bin/env bash

# fail hard
set -o pipefail
# fail harder
set -eu

function s3cmd_get_progress() {
	len=0
	while read line; do
		if [[ "$len" -gt 0 ]]; then
			# repeat a backspace $len times
			# need to use seq; {1..$len} doesn't work
			printf '%0.s\b' $(seq 1 $len)
		fi
		echo -n "$line"
		len=${#line}
	done < <(grep --line-buffered -o -P '(?<=\[)[0-9]+ of [0-9]+(?=\])' | awk -W interactive '{print int($1/$3*100)"% ("$1"/"$3")"}') # filter only the "[1 of 99]" bits from 's3cmd get' output and divide using awk
}

upload=false

# process flags
optstring=":-:"
while getopts "$optstring" opt; do
	case $opt in
		-)
			case "$OPTARG" in
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

if [[ $# == "1" ]]; then
	cat >&2 <<-EOF
		Usage: $(basename $0) [--upload] [S3_BUCKET S3_PREFIX [MANIFEST...]]
		  S3_BUCKET: S3 bucket name for packages.json upload; default: '\$S3_BUCKET'.
		  S3_PREFIX: S3 prefix, e.g. '' or 'dist-stable/'; default: '\$S3_PREFIX'.
		  
		  The environment variable '\$S3_REGION' is used to determine the bucket region;
		  it defaults to 's3' if not present. Use e.g. 's3.us-east-1' to set a region.
		  
		  If MANIFEST arguments are given, those are used to build the repo; otherwise,
		  all manifests from given or default S3_BUCKET+S3_PREFIX are downloaded.
		  
		  A --upload flag triggers immediate upload, otherwise instructions are printed.
		  
		  If --upload, or if stdout is a terminal, packages.json will be written to cwd.
		  If no --upload, and if stdout is a pipe, repo JSON will be echo'd to stdout.
	EOF
	exit 2
fi

here=$(cd $(dirname $0); pwd)

if [[ $# != "0" ]]; then
	S3_BUCKET=$1; shift
	S3_PREFIX=$1; shift
fi

S3_REGION=${S3_REGION:-s3}

if [[ $# == "0" ]]; then
	manifests_tmp=$(mktemp -d -t "dst-repo.XXXXX")
	trap 'rm -rf $manifests_tmp;' EXIT
	echo -n "-----> Fetching manifests... " >&2
	(
		cd $manifests_tmp
		s3cmd --host="${S3_REGION}.amazonaws.com" --host-bucket="%(bucket)s.${S3_REGION}.amazonaws.com" --ssl --progress get s3://${S3_BUCKET}/${S3_PREFIX}*.composer.json 2>&1 | tee download.log | s3cmd_get_progress >&2 || { echo -e "failed! Error:\n$(cat download.log)" >&2; exit 1; }
		rm download.log
	)
	echo "" >&2
	manifests=$manifests_tmp/*.composer.json
else
	manifests="$@"
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
	import itertools
	from distutils import version
	manifests = [ json.load(open(item)) for item in sys.argv[1:] if json.load(open(item)).get("type", "") != "heroku-sys-package" ]
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
	# this way, extension package formulae do not have to know about this ".native" business in theif formulae
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
	manifests.sort(
	    key=lambda package: (package.get("name"), version.LooseVersion(re.sub("[<>=*~^]", "0", package.get("require", {}).get("heroku-sys/php", "0.0.0")))),
	    reverse=True)
	# convert the list to a dict with package names as keys and list of versions (sorted by "php" requirement by previous sort) as values
	json.dump({"packages": dict((name, list(versions)) for name, versions in itertools.groupby(manifests, key=lambda package: package.get("name"))) }, sys.stdout, sort_keys=True)
PYTHON
) $manifests

# restore stdout
# note that 'exec >$(tty)' does not work as FD 1 may have been a pipe originally and not a tty
if $redir; then
	exec 1>&3 3>&-
fi

cmd="s3cmd --host=${S3_REGION}.amazonaws.com --host-bucket='%(bucket)s.${S3_REGION}.amazonaws.com' --ssl -m application/json put packages.json s3://${S3_BUCKET}/${S3_PREFIX}packages.json"
if $upload; then
	echo "-----> Uploading packages.json..." >&2
	eval "$cmd 1>&2"
	echo "-----> Done." >&2
elif [[ -t 1 ]]; then
	echo "-----> Done. Run '$cmd' to upload repository." >&2
fi
