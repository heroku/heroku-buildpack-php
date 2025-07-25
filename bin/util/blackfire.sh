#!/usr/bin/env bash

install_blackfire_ext() {
	# special treatment for Blackfire; we enable it if we detect a server id and a server token for it
	# otherwise users would have to have it in their require section, which is annoying in development environments
	BLACKFIRE_SERVER_ID=${BLACKFIRE_SERVER_ID:-}
	BLACKFIRE_SERVER_TOKEN=${BLACKFIRE_SERVER_TOKEN:-}
	if [[ -n "$BLACKFIRE_SERVER_TOKEN" && -n "$BLACKFIRE_SERVER_ID" ]] && ! platform-composer show --installed --quiet heroku-sys/ext-blackfire 2>/dev/null; then
		echo "- Blackfire config vars detected, installing ext-blackfire..." | indent
		if ! PHP_PLATFORM_INSTALLER_DISPLAY_OUTPUT_INDENT=9 platform-composer require --update-no-dev -- "heroku-sys/ext-blackfire:*" "heroku-sys/ext-blackfire.native:*" >> $build_dir/.heroku/php/install.log 2>&1; then
			mcount "warnings.addons.blackfire.extension_missing"
			warning_inline -i9 "no suitable version of ext-blackfire available"
		fi
	fi
}
