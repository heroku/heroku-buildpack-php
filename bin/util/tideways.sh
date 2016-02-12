#!/usr/bin/env bash

install_tideways_ext() {
    # we enable Tideways when we detect the TIDEWAYS_APIKEY environment variable.
    TIDEWAYS_APIKEY=${TIDEWAYS_APIKEY:-}
    if [[ "$engine" == "php" && ( ${#exts[@]} -eq 0 || ! ${exts[*]} =~ "tideways" ) && -n "$TIDEWAYS_APIKEY" ]]; then
        if $engine $(which composer) require --quiet --update-no-dev -d "$build_dir/.heroku/php" -- "heroku-sys/ext-tideways:*"; then
            install_ext "tideways" "add-on detected"
            exts+=("tideways")
        else
            warning_inline "Tideways detected, but no suitable extension available"
        fi
    fi
}

install_tideways_daemon() {
    cat > $build_dir/.profile.d/tideways.sh <<"EOF"
if [[ -n "$TIDEWAYS_APIKEY" ]]; then
    if [[ -f "/app/.heroku/php/bin/tideways-daemon" ]]; then
        /app/.heroku/php/bin/tideways-daemon -socket="/app/.heroku/tidewaysd.sock" &
    else
        echo >&2 "WARNING: Add-on 'tideways' detected, but PHP extension not yet installed. Push an update to the application to finish installation of the add-on; an empty change ('git commit --allow-empty') is sufficient."
    fi
fi
EOF
}

