#!/usr/bin/env bash

# fail hard
set -o pipefail
# fail harder
set -eu

if [[ $# -lt 2 ]]; then
	echo "Usage: $(basename $0) [--overwrite] FORMULA-VERSION" >&2
	exit 2
fi

# a helper (print_or_export_manifest_cmd) called in the script invoked by Bob will write to this if set
export MANIFEST_CMD=$(mktemp -t "manifest.XXXXX")

# pass through args (so users can pass --overwrite etc)
bob deploy "$@"

# invoke manifest upload
echo ""
echo "Uploading manifest..."
. $MANIFEST_CMD
