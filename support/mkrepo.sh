#!/usr/bin/env bash

# fail hard
set -o pipefail
# fail harder
set -eu

if [[ $# != "0" && $# != "2" ]]; then
	echo "Usage: $(basename $0) [S3_BUCKET S3_PREFIX]" >&2
	echo "  S3_BUCKET: S3 bucket name for packages.json upload; default: '\$S3_BUCKET'." >&2
	echo "  S3_PREFIX: S3 prefix, e.g. '/' or '/dist-stable/'; default: '/\${S3_PREFIX}/'." >&2
	echo " If stdout is a terminal, packages.json will be written to cwd." >&2
	echo " If stdout is a pipe, packages.json will be echo'd to stdout." >&2
	exit 2
fi

manifests_tmp=$(mktemp -d -t "dst-repo.XXXXX")
here=$(cd $(dirname $0); pwd)
trap 'rm -rf $manifests_tmp;' EXIT

echo "-----> Fetching manifests..." >&2
(
	cd $manifests_tmp
	s3cmd --ssl get s3://${1:-$S3_BUCKET}${2:-/$S3_PREFIX/}*.composer.json 1>&2
)

echo "-----> Generating packages.json..." >&2
if [[ -t 1 ]]; then
	# if stdout is a terminal; we write a "packages.json" instead of echoing
	# this is so other programs can capture the generated repo from stdout
	exec > packages.json
fi

# sort so that packages with the same name and version (e.g. ext-memcached 2.2.0) show up with their hhvm or php requirement in descending order - otherwise a Composer limitation means that a simple "ext-memcached: * + php: ^5.5.17" request would install 5.5.latest and not 5.6.latest, as it finds the 5.5.* requirement extension first and sticks to that instead of 5.6. For packages with identical names and versions (but different e.g. requirements), Composer basically treats them as equal and picks as a winner whatever it finds first. The requirements have to be written like "x.y.*" for this to work of course.
python -c 'import sys, json; from distutils import version; print json.dumps({"packages": [ sorted([json.load(open(item)) for item in sys.argv[1:]], key=lambda package: version.LooseVersion(package.get("require", {}).get("heroku-sys/hhvm", package.get("require", {}).get("heroku-sys/php", "0.0.0"))), reverse=True) ] })' $manifests_tmp/*.composer.json

if [[ -t 1 ]]; then
	echo "-----> Done. Run 's3cmd --ssl --access_key=\$AWS_ACCESS_KEY_ID --secret_key=\$AWS_SECRET_ACCESS_KEY --acl-public put packages.json s3://${1:-$S3_BUCKET}${2:-/$S3_PREFIX/}packages.json' to upload repository." >&2
fi
