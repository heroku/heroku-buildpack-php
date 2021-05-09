#!/bin/bash
# Build Path: /app/.heroku/php/

pecl install trader && sudo docker-php-ext-enable trader
echo -e "trader.real_precision=8" | sudo tee /usr/local/etc/php/php.ini