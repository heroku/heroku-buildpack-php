#!/usr/bin/env bash

# fail hard
set -o pipefail
# fail harder
set -eu

publish=true

S5CMD_OPTIONS=(${S5CMD_NO_SIGN_REQUEST:+--no-sign-request} ${S5CMD_PROFILE:+--profile "${S5CMD_PROFILE}"} --log error)

if [[ $# -lt "1" ]]; then
	cat >&2 <<-EOF
		Usage: $(basename "$0") MANIFEST...
		  MANIFEST: name of manifest, e.g. 'ext-event-2.0.0_php-7.4'
		  
		  Wildcard expansion for MANIFEST will be performed by s5cmd and can be combined
		  with shell brace expansion to match many formulae, for example:
		  $(basename "$0") php-8.1.{8..16} ext-{redis-4,newrelic-9}.*_php-7.*
		  
		  Bucket name and prefix will be read from '\$S3_BUCKET' and '\$S3_PREFIX'.
		  Bucket region (e.g. 'us-east-1') will be read from '\$S3_REGION', or detected
			automatically if not set.
	EOF
	exit 2
fi

S3_PREFIX=${S3_PREFIX:-}
# grep out the region (it's there even on 403 responses), and trim whitespace via xargs - important to use grep -o and discard trailing whitespace, otherwise we'll end up with a carriage return at the end of the value
S3_REGION=${S3_REGION:-$(set -o pipefail; curl -sI "https://${S3_BUCKET}.s3.amazonaws.com/" | grep -E -o -i "^x-amz-bucket-region:\s*\S+" | cut -d: -f2 | xargs || { echo >&2 "Failed to determine region for S3 bucket '$S3_BUCKET'"; exit 1; })}

here=$(cd "$(dirname "$0")"; pwd)

excludes=()
# iterate over args and normalize the optional .composer.json suffix
# we produce a list of '--exclude' options we feed to ‘s5cmd cp'
# any wildcards will be handled by s5cmd
for arg in "$@"; do
	manifest="${arg%.composer.json}.composer.json"
	excludes+=("--exclude" "${manifest}")
done

manifests_tmp=$(mktemp -d -t "dst-repo.XXXXX")
here=$(cd "$(dirname "$0")"; pwd)

# clean up at the end
trap 'popd > /dev/null; rm -rf "$manifests_tmp";' EXIT
# cd to tmp dir (without printing the dir stack)
pushd "$manifests_tmp" > /dev/null

echo "Fetching manifests, excluding given removals... " >&2
s5cmd "${S5CMD_OPTIONS[@]}" cp ${S3_REGION:+--source-region "$S3_REGION"} "${excludes[@]}" "s3://${S3_BUCKET}/${S3_PREFIX}*.composer.json" "$manifests_tmp" || { echo -e "\nFailed to fetch manifests! See message above for errors." >&2; exit 1; }

echo -e "\nNow performing a sync of the differences:\n" >&2

# we now simply treat this as a sync of packages between two folders, passing sync.sh the local dir as source and the remote as destination
# the "source" repository will have our matched manifests removed

"${here}/sync.sh" -s "$manifests_tmp" "$S3_BUCKET" "$S3_PREFIX" "$S3_REGION" "$S3_BUCKET" "$S3_PREFIX" "$S3_REGION"
