#!/usr/bin/env bash

# fail hard
set -o pipefail
# fail harder
set -eu

find_cmd=$(command -v gfind find | head -n1) # prefer gfind, since we use a GNU extension (-printf)

# default for $1
scan_dir=$(dirname "$BASH_SOURCE")/../
scan_dir=${1:-$scan_dir}

# Find using $find_cmd
# - in $scan_dir
# - first expression group:
#   - all directories
#   - that have a name starting with an underscore
#   - get pruned (removed)
# - second expression group:
#   - all files
#   - that match a name-with-version-number looking pattern
#   - get printed using their "nested path", meaning with the $scan_dir prefix removed
# Sort (with forced C collation for sorting) for stable hashing
# Calculate SHA256 hash
# Extract just the hash from sha256sum output
"$find_cmd" "$scan_dir" -type d -name '_*' -prune -or -type f -name '*-[0-9]*.[0-9]*' -printf '%P\n' \
  | LC_ALL=C sort --version-sort | sha256sum | cut -d" " -f1
