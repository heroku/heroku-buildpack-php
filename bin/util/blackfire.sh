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
if [[ -n "$BLACKFIRE_SERVER_TOKEN" && -n "$BLACKFIRE_SERVER_TOKEN" ]]; then
    touch /app/.heroku/php/var/blackfire/run/agent.sock
    /app/.heroku/php/bin/blackfire-agent -config=/app/.heroku/php/etc/blackfire/agent.ini -socket="unix:///app/.heroku/php/var/blackfire/run/agent.sock" &
fi
EOF
}
