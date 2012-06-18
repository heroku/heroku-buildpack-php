Nginx+PHP-FPM build pack
========================

This is a build pack bundling PHP and Nginx for Heroku apps.
Includes additional extensions: apc, memcache, memcached, phpredis, mcrypt.

Configuration
-------------

The config files are bundled:

* conf/nginx.conf.erb
* conf/etc.d/01_memcached.ini
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
$ export S3_BUCKET="heroku-buildpack-php-tyler" # set to your S3 bucket.
$ source support/set-env.sh
````
Edit `bin/compile` and `support/ec2-build-php.sh` to reflect the correct S3 bucket.

### Nginx
Run:
````
$ support/package_nginx
````
The binary package will be produced in the current directory. Upload it to Amazon S3.

### libmcrypt
Run:
````
$ support/package_libmcrypt
````
The binary package will be produced in the current directory. Upload it to Amazon S3.

### libmemcached
Run:
````
$ support/package_libmcrypt
````
The binary package will be produced in the current directory. Upload it to Amazon S3.

### PHP
PHP with mcrypt requires libmcrypt to be installed. Vulcan cannot be used to build in this case.

To pre-compile PHP for Heroku, spin up an Amazon EC2 instance within the US-East Region: `ami-04c9306d`. Refer to `support/ec2-up.sh` for some hints.

The use the following to compile PHP:
````
# after logging into EC2 instance, preferably with screen running.
$ curl -L "https://github.com/iphoting/heroku-buildpack-php-tyler/raw/master/support/ec2-build-php.sh" -o - | sudo bash
````
You should review the build script at <https://github.com/iphoting/heroku-buildpack-php-tyler/blob/master/support/ec2-build-php.sh>.

Usage
-----
To make your changes, fork this repo first and replace the following URLs with yours.

### Enabling New Relic
Copy `support/04_newrelic.ini.sample` to your heroku app as `conf/etc.d/04_newrelic.ini`, and edit as necessary.

Export your new relic license key as the `NEW_RELIC_LICENSE_KEY` env variable using `heroku config`. This is already done for you if you have the New Relic add on enabled.

### Deploying
To use this buildpack, on a new Heroku app:
````
heroku create -s cedar -b git://github.com/iphoting/heroku-buildpack-php-tyler.git
````

On an existing app:
````
heroku config:add BUILDPACK_URL=git://github.com/iphoting/heroku-buildpack-php-tyler.git
````

Push deploy your app and you should see Nginx, mcrypt, and PHP being bundled.

Credits
-------

Updated for Nginx+PHP support with memcache, phpredis, and mcrypt support by Ronald Ip from <https://github.com/heroku/heroku-buildpack-php>.

Credits to original authors.

