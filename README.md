Apache+PHP build pack
========================

This is a build pack bundling PHP and Apache for Heroku apps.

Configuration
-------------

The config files are bundled with the buildpack itself:

* conf/httpd.conf
* conf/php.ini


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
