#!/usr/bin/env bash

install_blackfire_ext() {
    # special treatment for Blackfire; we enable it if we detect a server id and a server token for it
    # otherwise users would have to have it in their require section, which is annoying in development environments
    BLACKFIRE_SERVER_ID=${BLACKFIRE_SERVER_ID:-}
    BLACKFIRE_SERVER_TOKEN=${BLACKFIRE_SERVER_TOKEN:-}
    if [[ "$engine" == "php" && -n "$BLACKFIRE_SERVER_TOKEN" && -n "$BLACKFIRE_SERVER_ID" ]] && ! $engine $(which composer) show -d "$build_dir/.heroku/php" --installed --quiet heroku-sys/ext-blackfire; then
        if $engine $(which composer) require --quiet --update-no-dev -d "$build_dir/.heroku/php" -- "heroku-sys/ext-blackfire:*"; then
            echo "- Blackfire detected, installed ext-blackfire" | indent
        else
            warning_inline "Blackfire detected, but no suitable extension available"
        fi
    fi
}
