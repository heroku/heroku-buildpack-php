#!/usr/bin/env bash

print_or_export_manifest_cmd() {
	if [[ "${MANIFEST_CMD:-}" ]]; then
		echo "$1" > "$MANIFEST_CMD"
	else
		echo "-----> Done. To upload manifest, run: $1"
	fi
}

generate_manifest_cmd() {
	cmd=(s5cmd ${S5CMD_NO_SIGN_REQUEST:+--no-sign-request} ${S5CMD_PROFILE:+--profile "$S5CMD_PROFILE"} cp ${S3_REGION:+--destination-region "$S3_REGION"} --content-type application/json "$(pwd)/${1}" "s3://${S3_BUCKET}/${S3_PREFIX}${1}")
	echo "${cmd[*]@Q}"
}

soname_version() {
	soname=$(objdump -p "$1" | grep SONAME | awk '{ printf $2; }')
	file=$(basename "$1")
	echo "${soname#${file}.}"
}
