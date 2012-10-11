#!/bin/bash
# vulcan build -v -c "./vulcan-build-php.sh" -p /app/vendor/php -o php-${PHP_VERSION}-with-fpm-heroku.tar.gz

## EDIT
source ./set-env.sh
## END EDIT

set -e
set -o pipefail

orig_dir=$( pwd )

mkdir -p build && pushd build

echo "+ Fetching libmcrypt libraries..."
# install mcrypt for portability.
mkdir -p /app/local
curl -L "https://s3.amazonaws.com/${S3_BUCKET}/libmcrypt-${LIBMCRYPT_VERSION}.tar.gz" -o - | tar xz -C /app/local

echo "+ Fetching libmemcached libraries..."
mkdir -p /app/local
curl -L "https://s3.amazonaws.com/${S3_BUCKET}/libmemcached-${LIBMEMCACHED_VERSION}.tar.gz" -o - | tar xz -C /app/local

echo "+ Fetching PHP sources..."
#fetch php, extract
curl -L http://us.php.net/get/php-$PHP_VERSION.tar.bz2/from/www.php.net/mirror -o - | tar xj

pushd php-$PHP_VERSION

echo "+ Configuring PHP..."
# new configure command
## WARNING: libmcrypt needs to be installed.
./configure \
--prefix=/app/vendor/php \
--with-config-file-path=/app/vendor/php \
--with-config-file-scan-dir=/app/vendor/php/etc.d \
--disable-debug \
--disable-rpath \
--enable-fpm \
--enable-gd-native-ttf \
--enable-inline-optimization \
--enable-libxml \
--enable-mbregex \
--enable-mbstring \
--enable-pcntl \
--enable-soap=shared \
--enable-zip \
--with-bz2 \
--with-curl \
--with-gd \
--with-gettext \
--with-jpeg-dir \
--with-mcrypt=/app/local \
--with-iconv \
--with-mhash \
--with-mysql \
--with-mysqli \
--with-openssl \
--with-pcre-regex \
--with-pdo-mysql \
--with-pgsql \
--with-pdo-pgsql \
--with-png-dir \
--with-zlib

echo "+ Compiling PHP..."
# build & install it
make install

popd

# update path
export PATH=/app/vendor/php/bin:$PATH

# configure pear
pear config-set php_dir /app/vendor/php

echo "+ Installing APC..."
# install apc from source
curl -L http://pecl.php.net/get/APC-${APC_VERSION}.tgz -o - | tar xz
pushd APC-${APC_VERSION}
# php apc jokers didn't update the version string in 3.1.10.
sed -i 's/PHP_APC_VERSION "3.1.9"/PHP_APC_VERSION "3.1.10"/g' php_apc.h
phpize
./configure --enable-apc --enable-apc-filehits --with-php-config=/app/vendor/php/bin/php-config
make && make install
popd

echo "+ Installing memcache..."
# install memcache

set +e
set +o pipefail
yes '' | pecl install memcache-beta
# answer questions
# "You should add "extension=memcache.so" to php.ini"
set -e
set -o pipefail


echo "+ Installing memcached from source..."
# install apc from source
curl -L http://pecl.php.net/get/memcached-${MEMCACHED_VERSION}.tgz -o - | tar xz
pushd memcached-${MEMCACHED_VERSION}
# edit config.m4 line 21 so no => yes ############### IMPORTANT!!! ###############
sed -i -e '21 s/no, no/yes, yes/' ./config.m4
sed -i -e '18 s/no, no/yes, yes/' ./config.m4
phpize
./configure --with-libmemcached-dir=/app/local --with-php-config=/app/vendor/php/bin/php-config
make && make install
popd

echo "+ Installing phpredis..."
# install phpredis
git clone git://github.com/nicolasff/phpredis.git
pushd phpredis
git checkout ${PHPREDIS_VERSION}

phpize
./configure
make && make install
# add "extension=redis.so" to php.ini
popd

echo "+ Install newrelic..."
curl -L "http://download.newrelic.com/php_agent/archive/${NEWRELIC_VERSION}/newrelic-php5-${NEWRELIC_VERSION}-linux.tar.gz" | tar xz
pushd newrelic-php5-${NEWRELIC_VERSION}-linux
cp -f agent/x64/newrelic-`phpize --version | grep "Zend Module Api No" | tr -d ' ' | cut -f 2 -d ':'`.so `php-config --extension-dir`/newrelic.so
popd

echo "+ Packaging PHP..."
# package PHP
echo ${PHP_VERSION} > /app/vendor/php/VERSION

popd

echo "+ Done!"

