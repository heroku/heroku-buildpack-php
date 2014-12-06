# Heroku buildpack: PHP

This is a [Heroku buildpack](http://devcenter.heroku.com/articles/buildpacks) for PHP applications.

It uses Composer for dependency management, supports PHP or HHVM (experimental) as runtimes, and offers a choice of Apache2 or Nginx web servers.

## Usage

You'll need to use at least an empty `composer.json` in your application.

    heroku config:set BUILDPACK_URL=https://github.com/heroku/heroku-buildpack-php
    echo '{}' > composer.json
    git add .
    git commit -am "add composer.json for PHP app detection"


Please refer to [Dev Center](https://devcenter.heroku.com/categories/php) for further usage instructions.

## Development

### Compiling Binaries

The folder `support/build` contains [Bob](http://github.com/kennethreitz/bob-builder) build scripts for all binaries and dependencies.

To get started with it, create a Python app (*Bob* is a Python application) on Heroku inside a clone of this repository, and set your S3 config vars:

```term
$ heroku create --buildpack https://github.com/heroku/heroku-buildpack-python
$ heroku ps:scale web=0
$ heroku config:set WORKSPACE_DIR=/app/support/build
$ heroku config:set AWS_ACCESS_KEY_ID=<your_aws_key>
$ heroku config:set AWS_SECRET_ACCESS_KEY=<your_aws_secret>
$ heroku config:set S3_BUCKET=<your_s3_bucket_name>
$ heroku config:set S3_PREFIX=<optional_s3_subfolder_to_upload_to>
```

Then, shell into an instance and run a build by giving the name of the formula inside `support/build`:

```term
$ heroku run bash
Running `bash` attached to terminal... up, run.6880
~ $ bob build php-5.5.11RC1

Fetching dependencies... found 2:
  - libraries/zlib
  - libraries/libmemcached
Building formula php-5.5.11RC1:
    === Building PHP
    Fetching PHP v5.5.11RC1 source...
    Compiling PHP v5.5.11RC1...
```

If this works, run `bob deploy` instead of `bob build` to have the result uploaded to S3 for you.

To speed things up drastically, it'll usually be a good idea to `heroku run bash --size PX` instead.

If the dependencies are not yet deployed, you can do so by e.g. running `bob deploy libraries/zlib`.

### Hacking

To work on this buildpack, fork it on Github. You can then use [Anvil with a local buildpack](https://github.com/ddollar/anvil-cli#iterate-on-buildpacks-without-pushing-to-github) to easily iterate on changes without pushing each time.

Alternatively, you may push changes to your fork (ideally in a branch if you'd like to submit pull requests), then create a test app with `heroku create --buildpack <your-github-url#branch>` and push to it.
