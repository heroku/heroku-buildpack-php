Apache+PHP build pack
========================

This is a build pack bundling PHP and Apache for Heroku apps.

Configuration
-------------

The config files are bundled with the buildpack itself:

* conf/httpd.conf
* conf/php.ini

Configure Heroku to use this buildpack repo AND branch. If you do not specify the branch, you will have unexpected results.

    heroku config:set BUILDPACK_URL=git://github.com/winglian/heroku-buildpack-php.git#master

Pre-compiling binaries
----------------------

    vulcan build -v -s ./build -p /tmp/build -c "./vulcan.sh"
    cp /tmp/build.tgz src/build.tgz

Hacking
-------

To change this buildpack, fork it on Github. Push up changes to your fork, then create a test app with --buildpack <your-github-url> and push to it.


Meta
----

Original buildpack by Pedro Belo. https://github.com/heroku/heroku-buildpack-php
