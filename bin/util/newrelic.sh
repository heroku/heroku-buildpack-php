#!/usr/bin/env bash

install_newrelic_ext() {
    # special treatment for New Relic; we enable it if we detect a license key for it
    # otherwise users would have to have it in their require section, which is annoying in development environments
    NEW_RELIC_LICENSE_KEY=${NEW_RELIC_LICENSE_KEY:-}
    if [[ ( ${#exts[@]} -eq 0 || ! ${exts[*]} =~ "newrelic" ) && -n "$NEW_RELIC_LICENSE_KEY" ]]; then
        install_ext "newrelic" "add-on detected"
        exts+=("newrelic")
    fi
}

install_newrelic_daemon() {
    # new relic defaults
    cat > $BUILD_DIR/.profile.d/newrelic.sh <<"EOF"
if [[ -n "$NEW_RELIC_LICENSE_KEY" ]]; then
    export NEW_RELIC_APP_NAME=${NEW_RELIC_APP_NAME:-"PHP Application on Heroku"}
    export NEW_RELIC_LOG_LEVEL=${NEW_RELIC_LOG_LEVEL:-"warning"}

    # The daemon is a spawned process, invoked by the PHP agent, which is truly
    # daemonized (i.e., it is disassociated from the controlling TTY and
    # running in the background). Therefore, the daemon is configured to write
    # its log output to a file instead of to STDIO 
    # (see .heroku/php/etc/php/conf.d/ext-newrelic.ini).
    #
    # Perpetually tail and redirect the daemon log file to stderr so that it
    # may be observed via 'heroku logs'.
    touch /tmp/heroku.ext-newrelic.newrelic-daemon.${PORT}.log
    tail -qF -n 0 /tmp/heroku.ext-newrelic.newrelic-daemon.${PORT}.log 1>&2 &
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
