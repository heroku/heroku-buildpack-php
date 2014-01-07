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

On a Heroku Dyno, one can run ``build.sh`` as executable text.  After
running it, `/app` will contain, among other entities,
`apache-2.2.25-2.tar.gz`, `php-5.3.27-2.tar.gz`, and
`mcrypt-2.5.8-2.tar.gz` which should be uploaded to a location that
can be downloaded by the build pack (see the URIs in `compile`).


Hacking
-------

To change this buildpack, fork it on Github. Push up changes to your fork, then create a test app with --buildpack <your-github-url> and push to it.


Meta
----

Created by Pedro Belo.
Many thanks to Keith Rarick for the help with assorted Unix topics :)
