#!/usr/bin/env bash

set -eu

command_name=${0##*/}

case "$command_name" in
	curl)
		printf '%s\0' "$@" > "$PIE_TEST_ROOT/curl.args"
		printf 'download\n' >> "$PIE_TEST_ROOT/events"
		while [[ $# -gt 0 ]]; do
			if [[ $1 == --output ]]; then
				printf 'This is a fake PIE download.\n' > "$2"
				exit
			fi
			shift
		done
		exit 1
		;;
	sha256sum)
		printf '%s\0' "$@" > "$PIE_TEST_ROOT/checksum.args"
		cat > "$PIE_TEST_ROOT/checksum.input"
		if [[ ${PIE_TEST_CHECKSUM_FAILURE:-0} == 1 ]]; then
			"$PIE_TEST_REAL_SHA256SUM" "$@" < "$PIE_TEST_ROOT/checksum.input"
		else
			printf 'verified\n' >> "$PIE_TEST_ROOT/events"
			touch "$PIE_TEST_ROOT/verified"
		fi
		;;
	php-config)
		case "$1" in
			--version) printf '%s\n' "$PIE_TEST_PHP_VERSION" ;;
			--extension-dir) printf '%s/lib/php/extensions/no-debug-non-zts-%s\n' "$PIE_TEST_OUT_PREFIX" "$PIE_TEST_PHP_API" ;;
			*) exit 1 ;;
		esac
		;;
	php)
		printf '%s\0' "$@" > "$PIE_TEST_ROOT/install.args"
		printf '%s\0' "$INSTALL_ROOT" "$PIE_WORKING_DIRECTORY" > "$PIE_TEST_ROOT/install.env"
		printf 'install\n' >> "$PIE_TEST_ROOT/events"
		[[ -f "$PIE_TEST_ROOT/verified" ]]
		[[ -f "$PIE_TEST_OUT_PREFIX/include/php/main/php.h" ]]
		mkdir -p "$PIE_WORKING_DIRECTORY"
		printf 'PIE state must stay outside the artifact\n' > "$PIE_WORKING_DIRECTORY/state"
		extension_dir=$INSTALL_ROOT$PIE_TEST_OUT_PREFIX/lib/php/extensions/no-debug-non-zts-$PIE_TEST_PHP_API
		mkdir -p "$extension_dir"
		printf 'built extension\n' > "$extension_dir/example.so"
		exit "${PIE_TEST_INSTALL_EXIT:-0}"
		;;
	phpize)
		exit 1
		;;
	nproc)
		printf '2\n'
		;;
	strip)
		printf '%s\0' "$@" > "$PIE_TEST_ROOT/strip.args"
		printf 'strip\n' >> "$PIE_TEST_ROOT/events"
		for target_path in "$@"; do :; done
		[[ -f "$target_path" ]]
		;;
	python)
		exec python3 "$@"
		;;
	*)
		exit 1
		;;
esac
