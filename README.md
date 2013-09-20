Apache+PHP build pack
========================

This is a build pack bundling PHP and Apache for Heroku apps.

Configuration
-------------

The config files are bundled with the build pack itself:

* conf/httpd.conf
* conf/php.ini


Pre-compiling binaries
----------------------

On a Heroku Dyno, one can run the following as executable text.  After
running it, `/app` will contain, among other entities,
`apache-2.2.25-1.tar.gz`, `php-5.3.27-1.tar.gz`, and
`mcrypt-2.5.8-1.tar.gz` which should be uploaded to a location that
can be downloaded by the build pack (see the URIs in `compile`).

    #!/bin/bash
    set -uex
    cd /tmp

    # Heroku revision.  Must match in 'compile' program.
    #
    # Affixed to all vendored binary output to represent changes to the
    # compilation environment without a change to the upstream version,
    # e.g. PHP 5.3.27 without, and then subsequently with, libmcrypt.
    heroku_rev='-2'

    # Clear /app directory
    find /app -mindepth 1 -print0 | xargs -0 rm -rf

    # Take care of vendoring libmcrypt
    mcrypt_version=2.5.8
    mcrypt_dirname=libmcrypt-$mcrypt_version
    mcrypt_archive_name=$mcrypt_dirname.tar.bz2

    # Download mcrypt if necessary
    if [ ! -f mcrypt_archive_name ]
    then
        curl -Lo $mcrypt_archive_name http://sourceforge.net/projects/mcrypt/files/Libmcrypt/2.5.8/libmcrypt-2.5.8.tar.bz2/download
    fi

    # Clean and extract mcrypt
    rm -rf $mcrypt_dirname
    tar jxf $mcrypt_archive_name

    # Build and install mcrypt.
    pushd $mcrypt_dirname
    ./configure --prefix=/app/vendor/mcrypt \
      --disable-posix-threads --enable-dynamic-loading
    make -s
    make install -s
    popd

    # Take care of vendoring Apache.
    httpd_version=2.2.25
    httpd_dirname=httpd-$httpd_version
    httpd_archive_name=$httpd_dirname.tar.bz2

    # Download Apache if necessary.
    if [ ! -f $httpd_archive_name ]
    then
        curl -LO ftp://ftp.osuosl.org/pub/apache//httpd/$httpd_archive_name
    fi

    # Clean and extract Apache.
    rm -rf $httpd_dirname
    tar jxf $httpd_archive_name

    # Build and install Apache.
    pushd $httpd_dirname
    ./configure --prefix=/app/apache --enable-rewrite --with-included-apr
    make -s
    make install -s
    popd

    # Take care of vendoring PHP.
    php_version=5.3.27
    php_dirname=php-$php_version
    php_archive_name=$php_dirname.tar.bz2

    # Download PHP if necessary.
    if [ ! -f $php_archive_name ]
    then
        curl -Lo $php_archive_name http://us1.php.net/get/php-5.3.27.tar.bz2/from/www.php.net/mirror
    fi

    # Clean and extract PHP.
    rm -rf $php_dirname
    tar jxf $php_archive_name

    # Compile PHP
    pushd $php_dirname
    ./configure --prefix=/app/php --with-apxs2=/app/apache/bin/apxs     \
    --with-mysql --with-pdo-mysql --with-pgsql --with-pdo-pgsql         \
    --with-iconv --with-gd --with-curl=/usr/lib                         \
    --with-config-file-path=/app/php --enable-soap=shared               \
    --with-openssl --with-mcrypt=/app/vendor/mcrypt --enable-sockets
    make -s
    make install -s
    popd

    # Copy in MySQL client library.
    mkdir -p /app/php/lib/php
    cp /usr/lib/libmysqlclient.so.16 /app/php/lib/php

    # 'apc' installation
    #
    # $PATH manipulation Necessary for 'pecl install', which relies on
    # PHP binaries relative to $PATH.

    export PATH=/app/php/bin:$PATH
    /app/php/bin/pecl channel-update pecl.php.net

    # Use defaults for apc build prompts.
    yes '' | /app/php/bin/pecl install apc

    # Sanitize default cgi-bin to rid oneself of Apache sample
    # programs.
    find /app/apache/cgi-bin/ -mindepth 1 -print0 | xargs -0 rm -r

    # Stamp and archive binaries.
    pushd /app
    echo $mcrypt_version > vendor/mcrypt/VERSION
    tar -zcf mcrypt-"$mcrypt_version""$heroku_rev".tar.gz vendor/mcrypt
    echo $httpd_version > apache/VERSION
    tar -zcf apache-"$httpd_version""$heroku_rev".tar.gz apache
    echo $php_version > php/VERSION
    tar -zcf php-"$php_version""$heroku_rev".tar.gz php
    popd
	

Uploading binaries immediately after compiling
----------------------------------------------

WARNING: One ought not log out of the 'heroku bash' shell after compiling-- doing so would destroy the files that just took 20 minutes to compile!  This is both the curse and (in performance) the magic of the ephemeral filesystem.

Instead, one can run the following as executable text, in order to whisk those files out to Amazon S3 immediately.

    #!/bin/bash
    set -uex

    # configure amazon
    AMAZON_KEY_ID="A12345WZ12345KL12345"
    AMAZON_SECRET="a123457U12345+D12345aB12345tE12345RZ123P"
    AMAZON_BUCKET_NAME="lorem-ipsum"

    # function to put files
    function put_file() {
        local FILENAME="$1"
        ./s3-put -k "$AMAZON_KEY_ID" -s secret -T "$FILENAME" "/$AMAZON_BUCKET_NAME/$FILENAME"
    }

    # go to folder
    cd /app

    # download and unpack s3-bash
    curl -O https://s3-bash.googlecode.com/files/s3-bash.0.02.tar.gz
    tar -xf s3-bash.0.02.tar.gz
    chmod a+x s3-*

    # store the secret
    printf "$AMAZON_SECRET" > secret

    # put the files
    put_file apache-2.2.25.tar.gz
    put_file php-5.3.27.tar.gz
    put_file mcrypt-2.5.8.tar.gz

    # the last step is making those three files public on AWS.
    # when complete, they will be publicly accessible at:
    #  http://lorem-ipsum.s3.amazonaws.com/php-5.3.27.tar.gz
    #  http://lorem-ipsum.s3.amazonaws.com/apache-2.2.25.tar.gz
    #  http://lorem-ipsum.s3.amazonaws.com/mcrypt-2.5.8.tar.gz
		

Hacking
-------

To change this buildpack, fork it on Github. Push up changes to your fork, then create a test app with --buildpack <your-github-url> and push to it.


Meta
----

Created by Pedro Belo.
Many thanks to Keith Rarick for the help with assorted Unix topics :)
