#!/bin/bash

print_or_export_manifest_cmd() {
    if [[ "${MANIFEST_CMD:-}" ]]; then
        echo "$1" > $MANIFEST_CMD
    else
        echo "-----> Done. Run '$1' to upload manifest."
    fi
}

generate_manifest_cmd() {
    echo "s3cmd --ssl${AWS_ACCESS_KEY_ID+" --access_key=\$AWS_ACCESS_KEY_ID"}${AWS_SECRET_ACCESS_KEY+" --secret_key=\$AWS_SECRET_ACCESS_KEY"} --acl-public put $(pwd)/$1 s3://$S3_BUCKET/$S3_PREFIX/$1"
}