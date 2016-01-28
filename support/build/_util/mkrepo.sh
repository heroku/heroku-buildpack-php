#!/usr/bin/env bash

# fail hard
set -o pipefail
# fail harder
set -eu

if [[ $# == "1" ]]; then
	echo "Usage: $(basename $0) [S3_BUCKET S3_PREFIX [MANIFEST...]]" >&2
	echo "  S3_BUCKET: S3 bucket name for packages.json upload; default: '\$S3_BUCKET'." >&2
	echo "  S3_PREFIX: S3 prefix, e.g. '/' or '/dist-stable/'; default: '/\${S3_PREFIX}/'." >&2
	echo "  If MANIFEST arguments are given, those are used to build the repo; otherwise," >&2
	echo "   all manifests from given or default S3_BUCKET+S3_PREFIX are downloaded." >&2
	echo " If stdout is a terminal, packages.json will be written to cwd." >&2
	echo " If stdout is a pipe, packages.json will be echo'd to stdout." >&2
	exit 2
fi

here=$(cd $(dirname $0); pwd)

if [[ $# != "0" ]]; then
	S3_BUCKET=$1; shift
	S3_PREFIX=$1; shift
else
	S3_PREFIX="/${S3_PREFIX}/"
fi

if [[ $# == "0" ]]; then
	manifests_tmp=$(mktemp -d -t "dst-repo.XXXXX")
	trap 'rm -rf $manifests_tmp;' EXIT
	echo "-----> Fetching manifests..." >&2
	(
		cd $manifests_tmp
		s3cmd --ssl get s3://${S3_BUCKET}${S3_PREFIX}*.composer.json 1>&2
	)
	manifests=$manifests_tmp/*.composer.json
else
	manifests="$@"
fi

echo "-----> Generating packages.json..." >&2
if [[ -t 1 ]]; then
	# if stdout is a terminal; we write a "packages.json" instead of echoing
	# this is so other programs can capture the generated repo from stdout
	exec > packages.json
fi

# sort so that packages with the same name and version (e.g. ext-memcached 2.2.0) show up with their hhvm or php requirement in descending order - otherwise a Composer limitation means that a simple "ext-memcached: * + php: ^5.5.17" request would install 5.5.latest and not 5.6.latest, as it finds the 5.5.* requirement extension first and sticks to that instead of 5.6. For packages with identical names and versions (but different e.g. requirements), Composer basically treats them as equal and picks as a winner whatever it finds first. The requirements have to be written like "x.y.*" for this to work of course.
python -c 'import sys, json; from distutils import version; json.dump({"packages": [ sorted([json.load(open(item)) for item in sys.argv[1:]], key=lambda package: version.LooseVersion(package.get("require", {}).get("heroku-sys/hhvm", package.get("require", {}).get("heroku-sys/php", "0.0.0"))), reverse=True) ] }, sys.stdout, sort_keys=True)' $manifests

echo "-----> Done. Run 's3cmd --ssl${AWS_ACCESS_KEY_ID+" --access_key=\$AWS_ACCESS_KEY_ID"}${AWS_SECRET_ACCESS_KEY+" --secret_key=\$AWS_SECRET_ACCESS_KEY"} --acl-public put packages.json s3://${S3_BUCKET}${S3_PREFIX}packages.json' to upload repository." >&2
