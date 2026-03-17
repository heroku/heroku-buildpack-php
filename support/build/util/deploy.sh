#!/usr/bin/env bash

# fail hard
set -o pipefail
# fail harder
set -eu

help=false
dry_run=false
publish=false

# process flags
optstring=":-:h"
while getopts "$optstring" opt; do
	case $opt in
		h)
			help=true
			;;
		-)
			case "$OPTARG" in
				help)
					help=true
					;;
				dry-run)
					dry_run=true
					break
					;;
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
# clear processed arguments
shift $((OPTIND-1))

if $help || [[ $# -lt 1 ]]; then
	cat >&2 <<-EOF
		Usage: $(basename "$0") --dry-run FORMULA-VERSION
		  With --dry-run, a 'bob build' will be performed instead of a 'bob deploy'.
		Usage: $(basename "$0") [--publish] FORMULA-VERSION [--overwrite]
		  If --publish is given, mkrepo.sh will be invoked after a successful deploy to
		  re-generate the repo. CAUTION: this will cause all manifests in the bucket to
		  be included in the repo, including potentially currently unpublished ones.
		  All additional arguments, including --overwrite, are passed through to 'bob'.
	EOF
	exit 2
fi

if ! $dry_run && [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
	echo '$AWS_ACCESS_KEY_ID or $AWS_SECRET_ACCESS_KEY not set!' >&2
	exit 2
fi

# a helper (print_or_export_manifest_cmd) called in the script invoked by Bob will write to this if set
MANIFEST_CMD=$(mktemp -t "manifest.XXXXX")
# a log for capturing the inner formula exit status
bob_log=$(mktemp -t "bob-log.XXXXX")
export MANIFEST_CMD
trap 'rm -f "$MANIFEST_CMD" "$bob_log";' EXIT

# make sure we start cleanly
rm -rf /app/.heroku/php

# pass through args (so users can pass --overwrite etc)
# but modify any path by stripping $WORKSPACE_DIR from the front, if it's there
# so that one can also pass in the full path to the formula relative to the root, and not just relative to $WORKSPACE_DIR
# that allows for simpler mass build loops using wildcards without having to worry about the relative location of other references such as an --env-file, like:
# for f in support/build/packages/php-8.{4,5}.* support/build/packages/ext-{redis,blackfire,imagick}-*_php-8.{4,5}; do docker run --rm --tty --interactive --env-file=../dockerenv.heroku-22 heroku-php-builder-heroku-22 deploy.sh $f; done
args=()
for var in "$@"; do
	expanded="$(pwd)/$var"
	if [[ -f $expanded ]]; then
		var="${expanded#$WORKSPACE_DIR/}"
	fi
	args+=("$var")
done

bob $($dry_run && echo "build" || echo "deploy") "${args[@]}" |& tee "$bob_log" || {
	orig_status=$?
	# bob does not forward the exit status of the formula, but exits 1 and prints something like this to stderr:
	# ERROR: Formula exited with return code 9.
	inner_status=$(grep -Po "(?<=^ERROR: Formula exited with return code )\d(?=\.$)" "$bob_log") || {
		# It wasn't that, so we return the original exit status, unless the archive existed, then we return status 5
		grep -qE "^ERROR: Archive .+ already exists\.$" "$bob_log" && exit 5 || exit "$orig_status"
	}
	exit "$inner_status"
}

$dry_run && exit

# invoke manifest upload
echo ""
echo "Uploading manifest..."
. "$MANIFEST_CMD"

if $publish; then
	echo "Updating repository..."
	"$(dirname "$BASH_SOURCE")/mkrepo.sh" --upload
fi
