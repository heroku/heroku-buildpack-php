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
	done < <(grep --line-buffered -o -E '\[[0-9]+ of [0-9]+\]') # filter only the "[1 of 99]" bits from 's3cmd get' output
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
		  S3_PREFIX: S3 prefix, e.g. '' or 'dist-stable/'; default: '\${S3_PREFIX}'.
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

if [[ $# == "0" ]]; then
	manifests_tmp=$(mktemp -d -t "dst-repo.XXXXX")
	trap 'rm -rf $manifests_tmp;' EXIT
	echo -n "-----> Fetching manifests... " >&2
	(
		cd $manifests_tmp
		s3cmd --ssl --progress get s3://${S3_BUCKET}/${S3_PREFIX}*.composer.json 2>&1 | tee download.log | s3cmd_get_progress >&2 || { echo -e "failed! Error:\n$(cat download.log)" >&2; exit 1; }
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

# sort so that packages with the same name and version (e.g. ext-memcached 2.2.0) show up with their php requirement in descending order - otherwise a Composer limitation means that a simple "ext-memcached: * + php: ^7.0.0" request would install 7.0.latest and not 7.4.latest, as it finds the 7.0.* requirement extension first and sticks to that instead of 7.4. For packages with identical names and versions (but different e.g. requirements), Composer basically treats them as equal and picks as a winner whatever it finds first. The requirements have to be written like "x.y.*" for this to work of course (we replace "*", "<=" and so forth with "0", as that's fine for the purpose of just sorting - otherwise, a comparison of e.g. "^7.0.0" and "7.0.*" would cause "TypeError: '<' not supported between instances of 'str' and 'int'")
python -c 'import sys, re, json; from distutils import version; json.dump({"packages": [ sorted([json.load(open(item)) for item in sys.argv[1:] if json.load(open(item)).get("type", "") != "heroku-sys-package"], key=lambda package: version.LooseVersion(re.sub("[<>=*~^]", "0", package.get("require", {}).get("heroku-sys/php", "0.0.0"))), reverse=True) ] }, sys.stdout, sort_keys=True)' $manifests

# restore stdout
# note that 'exec >$(tty)' does not work as FD 1 may have been a pipe originally and not a tty
if $redir; then
	exec 1>&3 3>&-
fi

cmd="s3cmd --ssl${AWS_ACCESS_KEY_ID+" --access_key=\$AWS_ACCESS_KEY_ID"}${AWS_SECRET_ACCESS_KEY+" --secret_key=\$AWS_SECRET_ACCESS_KEY"} --acl-public -m application/json put packages.json s3://${S3_BUCKET}/${S3_PREFIX}packages.json"
if $upload; then
	echo "-----> Uploading packages.json..." >&2
	eval "$cmd 1>&2"
	echo "-----> Done." >&2
elif [[ -t 1 ]]; then
	echo "-----> Done. Run '$cmd' to upload repository." >&2
fi
