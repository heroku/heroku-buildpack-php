#!/bin/bash
# Build Path: /app/.heroku/php/
dep_url=git://github.com/phalcon/cphalcon.git
phalcon_dir=cphalcon
echo "-----> Building Phalcon..."

### Phalcon
echo "[LOG] Downloading PhalconPHP"
git clone $dep_url -q
if [ ! -d "$phalcon_dir" ]; then
  echo "[ERROR] Failed to find phalconphp directory $phalcon_dir"
  exit
fi
cd $phalcon_dir/build

# /app/php/bin/phpize
# ./configure --enable-phalcon --with-php-config=$PHP_ROOT/bin/php-config
# make
# make install
BUILD_DIR=$1
ln -s $BUILD_DIR/.heroku /app/.heroku
export PATH=/app/.heroku/php/bin:$PATH
bash ./install
cd
echo "important extension phalcon into php.ini"
echo "extension=phalcon.so" >> /app/.heroku/php/etc/php/php.ini

