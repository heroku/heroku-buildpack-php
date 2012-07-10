Apache+PHP build pack
========================

This is a build pack bundling PHP and Apache for Heroku apps.

Configuration
-------------

The config files are bundled with the LP itself:

* conf/httpd.conf
* conf/php.ini


Pre-compiling binaries
----------------------

    # apache
    mkdir /app
    curl -O http://apache.cyberuse.com/httpd/httpd-2.2.22.tar.gz
    tar xvzf httpd-2.2.22.tar.gz
    cd httpd-2.2.22
    ./configure --prefix=/app/apache --enable-rewrite --enable-proxy --enable-proxy-http
    make
    make install
    cd ..
    
    # php
    curl -LO http://us2.php.net/get/php-5.3.14.tar.gz/from/us.php.net/mirror
    mv mirror php.tar.gz
    tar xzvf php.tar.gz
    cd php-5.3.14/
    ./configure --prefix=/app/php --with-apxs2=/app/apache/bin/apxs --with-mysql --with-pdo-mysql --with-pgsql --with-pdo-pgsql --with-iconv --with-gd --with-curl=/usr/lib --with-config-file-path=/app/php --enable-soap=shared --with-openssl
    make
    make install
    cd ..
    
    # php extensions
    mkdir /app/php/ext
    cp /usr/lib/libmysqlclient.so.16 /app/php/ext/
    
    # pear
    apt-get install php5-dev php-pear
    pear config-set php_dir /app/php
    pecl install apc
    mkdir /app/php/include/php/ext/apc
    cp /usr/lib/php5/20060613/apc.so /app/php/ext/
    cp /usr/include/php5/ext/apc/apc_serializer.h /app/php/include/php/ext/apc/
    
    
    # package
    cd /app
    echo '2.2.22' > apache/VERSION
    tar -zcvf apache.tar.gz apache
    echo '5.3.14' > php/VERSION
    tar -zcvf php.tar.gz php


Hacking
-------

To change this buildpack, fork it on Github. Push up changes to your fork, then create a test app with --buildpack <your-github-url> and push to it.


Meta
----

Created by Pedro Belo.
Many thanks to Keith Rarick for the help with assorted Unix topics :)