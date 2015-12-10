#!/usr/bin/env bash

# fail hard
set -o pipefail
# fail harder
set -eux

echo "-----> Fetching manifests..."
s3cmd --ssl get s3://$S3_BUCKET/$S3_PREFIX/*.composer.json

echo "-----> Generating packages.json..."
python -c 'import sys, json; print json.dumps({"packages": [ [json.load(open(item)) for item in sys.argv[1:]] ] })' *.composer.json > packages.json

echo "-----> Done. Run 's3cmd --ssl --access_key=\$AWS_ACCESS_KEY_ID --secret_key=\$AWS_SECRET_ACCESS_KEY --acl-public put packages.json s3://$S3_BUCKET/$S3_PREFIX/packages.json' to upload repository."
