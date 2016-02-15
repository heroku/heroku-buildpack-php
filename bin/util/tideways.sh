#!/usr/bin/env bash

install_tideways_ext() {
    # we enable Tideways when we detect the TIDEWAYS_APIKEY environment variable.
    TIDEWAYS_APIKEY=${TIDEWAYS_APIKEY:-}
    if [[ "$engine" == "php" && -n "$TIDEWAYS_APIKEY" ]] && ! $engine $(which composer) show -d "$build_dir/.heroku/php" --installed --quiet heroku-sys/ext-tideways; then
        if $engine $(which composer) require --quiet --update-no-dev -d "$build_dir/.heroku/php" -- "heroku-sys/ext-tideways:*"; then
            echo "- Tideways detected, installed ext-tideways" | indent
        else
            warning_inline "Tideways detected, but no suitable extension available"
        fi
    fi
}

