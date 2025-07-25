#!/usr/bin/env bash

install_newrelic_ext() {
	# special treatment for New Relic; we enable it if we detect a license key for it
	# otherwise users would have to have it in their require section, which is annoying in development environments
	NEW_RELIC_LICENSE_KEY=${NEW_RELIC_LICENSE_KEY:-}
	if [[ -n "$NEW_RELIC_LICENSE_KEY" ]] && ! platform-composer show --installed --quiet heroku-sys/ext-newrelic 2>/dev/null; then
		echo "- New Relic config var detected, installing ext-newrelic..." | indent
		if ! PHP_PLATFORM_INSTALLER_DISPLAY_OUTPUT_INDENT=9 platform-composer require --update-no-dev -- "heroku-sys/ext-newrelic:*" "heroku-sys/ext-newrelic.native:*" >> $build_dir/.heroku/php/install.log 2>&1; then
			mcount "warnings.addons.newrelic.extension_missing"
			warning_inline -i9 "no suitable version of ext-newrelic available"
		fi
	fi
}

install_newrelic_userini() {
	if [[ -n "${NEW_RELIC_CONFIG_FILE:-}" ]]; then
		if [[ ! -f "${NEW_RELIC_CONFIG_FILE}" ]]; then
			mcount "failures.addons.newrelic.NEW_RELIC_CONFIG_FILE"
			error <<-EOF
				Config var 'NEW_RELIC_CONFIG_FILE' points to non existing file
				'${NEW_RELIC_CONFIG_FILE}'
			EOF
		fi
		notice_inline "Using custom New Relic config '${NEW_RELIC_CONFIG_FILE}'"
		( cd $build_dir/.heroku/php/etc/php/conf.d; ln -s "../../../../../${NEW_RELIC_CONFIG_FILE}" "ext-newrelic.user.ini" )
	fi
}
