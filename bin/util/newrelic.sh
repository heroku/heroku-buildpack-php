#!/usr/bin/env bash

install_newrelic_ext() {
    # special treatment for New Relic; we enable it if we detect a license key for it
    # otherwise users would have to have it in their require section, which is annoying in development environments
    NEW_RELIC_LICENSE_KEY=${NEW_RELIC_LICENSE_KEY:-}
    if [[ "$engine" == "php" && ( ${#exts[@]} -eq 0 || ! ${exts[*]} =~ "newrelic" ) && -n "$NEW_RELIC_LICENSE_KEY" ]]; then
        if $engine $(which composer) require --quiet --update-no-dev -d "$BUILD_DIR/.heroku/php" -- "heroku-sys/ext-newrelic:*"; then
            install_ext "newrelic" "add-on detected"
            exts+=("newrelic")
        else
            warning_inline "New Relic detected, but no suitable extension available"
        fi
    fi
}

install_newrelic_daemon() {
    # new relic defaults
    cat > $BUILD_DIR/.profile.d/newrelic.sh <<"EOF"
if [[ -n "$NEW_RELIC_LICENSE_KEY" ]]; then
    if [[ -f "/app/.heroku/php/bin/newrelic-daemon" ]]; then
        export NEW_RELIC_APP_NAME=${NEW_RELIC_APP_NAME:-"PHP Application on Heroku"}
        export NEW_RELIC_LOG_LEVEL=${NEW_RELIC_LOG_LEVEL:-"warning"}

        # The daemon is a started in foreground mode so it will not daemonize
        # (i.e. disassociate from the controlling TTY and disappear into the
        # background).
        #
        # Perpetually tail and redirect the daemon log file to stderr so that it
        # may be observed via 'heroku logs'.
        touch /tmp/heroku.ext-newrelic.newrelic-daemon.${PORT}.log
        tail -qF -n 0 /tmp/heroku.ext-newrelic.newrelic-daemon.${PORT}.log 1>&2 &
        
        # daemon start
        /app/.heroku/php/bin/newrelic-daemon -f -l "/tmp/heroku.ext-newrelic.newrelic-daemon.${PORT}.log" -d "${NEW_RELIC_LOG_LEVEL}" -p "/tmp/newrelic-daemon.pid" &
        
        # give it a moment to connect
        sleep 2
    else
        echo >&2 "WARNING: Add-on 'newrelic' detected, but PHP extension not yet installed. Push an update to the application to finish installation of the add-on; an empty change ('git commit --allow-empty') is sufficient."
    fi
fi
EOF
}

install_newrelic_userini() {
    if [[ -n "${NEW_RELIC_CONFIG_FILE:-}" ]]; then
        if [[ ! -f "${NEW_RELIC_CONFIG_FILE}" ]]; then
            error "Config var 'NEW_RELIC_CONFIG_FILE' points to non existing file
'${NEW_RELIC_CONFIG_FILE}'"
        fi
        notice_inline "Using custom New Relic config '${NEW_RELIC_CONFIG_FILE}'"
        ( cd $BUILD_DIR/.heroku/php/etc/php/conf.d; ln -s "../../../../../${NEW_RELIC_CONFIG_FILE}" "ext-newrelic.user.ini" )
    fi
}
