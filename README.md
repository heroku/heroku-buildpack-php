Nginx+PHP-FPM build pack
========================

This is a build pack bundling PHP and Nginx for Heroku apps.
Includes additional extensions: apc, memcache, phpredis, mcrypt.

Configuration
-------------

The config files are bundled:

* conf/nginx.conf.erb
* conf/etc.d/01_apc.ini
* conf/etc.d/02_memcache.ini
* conf/etc.d/03_phpredis.ini
* conf/php.ini
* conf/php-fpm.conf

### Overriding Configuration Files in During Deployment

Create a `conf/` directory in the root of the your deployment. Any files with names matching the above will be copied over and overwitten.

This way, you can customise settings specific to your application, especially the document root in `nginx.conf.erb`. (Note the .erb extension.)


Pre-compiling binaries
----------------------

### Preparation
Edit `support/set-env.sh` and `bin/compile` to update the version numbers.
````
$ export AWS_ID="1BHAJK48DJFMQKZMNV93" # optional if s3 handled manually.
$ export AWS_SECRET="fj2jjchebsjksmMJCN387RHNjdnddNfi4jjhshh3" # as above
$ export S3_BUCKET="buildpack-php"
$ source support/set-env.sh
````

### Nginx
First, edit or comment out the last line of `support/package_nginx` to reflect the correct command to upload to s3.

Then, run it:
````
$ support/package_nginx
````

### PHP
Refer to gist: <https://gist.github.com/2650976> to compile PHP on AWS EC2. Vulcan build machine times out with this upload.
<script src="https://gist.github.com/2650976.js"> </script>

Usage
-----
To use this buildpack, on a new Heroku app:
````
heroku create -s cedar -b git://github.com/iphoting/heroku-buildpack-php-tyler.git
````

On an existing app:
````
heroku config:add BUILDPACK_URL=git://github.com/iphoting/heroku-buildpack-php-tyler.git
````

Push deploy your app and you should see Nginx, mcrypt, and PHP being bundled.

Hacking
-------

To change this buildpack, fork it on Github. Push up changes to your fork, then create a test app with --buildpack <your-github-url> and push to it.


Credits
-------

Updated for Nginx+PHP support with memcache, phpredis, and mcrypt support by Ronald Ip from <https://github.com/heroku/heroku-buildpack-php>.

Credits to original authors.

