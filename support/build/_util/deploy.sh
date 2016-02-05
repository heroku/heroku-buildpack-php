#!/usr/bin/env bash

# fail hard
set -o pipefail
# fail harder
set -eu

if [[ $# -lt 1 ]]; then
	echo "Usage: $(basename $0) [--overwrite] FORMULA-VERSION" >&2
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
