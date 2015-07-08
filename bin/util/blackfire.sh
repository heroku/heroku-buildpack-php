#!/usr/bin/env bash

install_blackfire_ext() {
    # special treatment for Blackfire; we enable it if we detect a server id and a server token for it
    # otherwise users would have to have it in their require section, which is annoying in development environments
    BLACKFIRE_SERVER_ID=${BLACKFIRE_SERVER_ID:-}
    BLACKFIRE_SERVER_TOKEN=${BLACKFIRE_SERVER_TOKEN:-}
    if [[ ( ${#exts[@]} -eq 0 || ! ${exts[*]} =~ "blackfire" ) && -n "$BLACKFIRE_SERVER_TOKEN" && -n "$BLACKFIRE_SERVER_ID" ]]; then
        install_ext "blackfire" "add-on detected"
        exts+=("blackfire")
    fi
}

install_blackfire_agent() {
    # blackfire defaults
    cat > $BUILD_DIR/.profile.d/blackfire.sh <<"EOF"
if [[ -n "$BLACKFIRE_SERVER_TOKEN" && -n "$BLACKFIRE_SERVER_ID" ]]; then
    if [[ -f "/app/.heroku/php/bin/blackfire-agent" ]]; then
        touch /app/.heroku/php/var/blackfire/run/agent.sock
        /app/.heroku/php/bin/blackfire-agent -config=/app/.heroku/php/etc/blackfire/agent.ini -socket="unix:///app/.heroku/php/var/blackfire/run/agent.sock" &
    else
        echo >&2 "WARNING: Add-on 'blackfire' detected, but PHP extension not yet installed. Push an update to the application to finish installation of the add-on; an empty change ('git commit --allow-empty') is sufficient."
    fi
fi
EOF
}
