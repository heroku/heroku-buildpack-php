#!/usr/bin/env bash

# fail hard
set -o pipefail
# fail harder
set -eu

publish=false

# process flags
optstring=":-:"
while getopts "$optstring" opt; do
	case $opt in
		-)
			case "$OPTARG" in
				publish)
					publish=true
					break
					;;
				*)
					OPTIND=1
					break
					;;
			esac
	esac
done
# clear processed "publish" argument
shift $((OPTIND-1))

if [[ $# -lt 1 ]]; then
	echo "Usage: $(basename $0) [--publish] FORMULA-VERSION [--overwrite]" >&2
	echo "  If --publish is given, mkrepo.sh will be invoked after a successful deploy to" >&2
	echo "  re-generate the repo. CAUTION: this will cause all manifests in the bucket to" >&2
	echo "  be included in the repo, including potentially currently unpublished ones." >&2
	echo " All additional arguments, including --overwrite, are passed through to 'bob'." >&2
	exit 2
fi

if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
	echo '$AWS_ACCESS_KEY_ID or $AWS_SECRET_ACCESS_KEY not set!' >&2
	exit 2
fi

# a helper (print_or_export_manifest_cmd) called in the script invoked by Bob will write to this if set
export MANIFEST_CMD=$(mktemp -t "manifest.XXXXX")
trap 'rm -rf $MANIFEST_CMD;' EXIT

# make sure we start cleanly
rm -rf /app/.heroku/php

# pass through args (so users can pass --overwrite etc)
bob deploy "$@"

# invoke manifest upload
echo ""
echo "Uploading manifest..."
. $MANIFEST_CMD

if $publish; then
	echo "Updating repository..."
	$(dirname $BASH_SOURCE)/mkrepo.sh --upload "$S3_BUCKET" "${S3_PREFIX}"
fi
