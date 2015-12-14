#!/usr/bin/env bash

# fail hard
set -o pipefail
# fail harder
set -eux

echo "-----> Fetching manifests..."
s3cmd --ssl get s3://$S3_BUCKET/$S3_PREFIX/*.composer.json

echo "-----> Generating packages.json..."
# sort so that packages with the same name and version (e.g. ext-memcached 2.2.0) show up with their hhvm or php requirement in descending order - otherwise a Composer limitation means that a simple "ext-memcached: * + php: ^5.5.17" request would install 5.5.latest and not 5.6.latest, as it finds the 5.5.* requirement extension first and sticks to that instead of 5.6. For packages with identical names and versions (but different e.g. requirements), Composer basically treats them as equal and picks as a winner whatever it finds first. The requirements have to be written like "x.y.*" for this to work of course.
python -c 'import sys, json; from distutils import version; print json.dumps({"packages": [ sorted([json.load(open(item)) for item in sys.argv[1:]], key=lambda package: version.LooseVersion(package.get("require", {}).get("heroku-sys/hhvm", package.get("require", {}).get("heroku-sys/php", "0.0.0"))), reverse=True) ] })' *.composer.json > packages.json

echo "-----> Done. Run 's3cmd --ssl --access_key=\$AWS_ACCESS_KEY_ID --secret_key=\$AWS_SECRET_ACCESS_KEY --acl-public put packages.json s3://$S3_BUCKET/$S3_PREFIX/packages.json' to upload repository."
