# Building Custom Platform Packages and Repositories

## Introduction

**Please note that Heroku cannot provide support for issues related to custom platform repositories and packages.**

### How it all works

When an application is deployed, `bin/compile` extracts all platform dependencies from the application's `composer.lock` and constructs a new `composer.json` (with all package names prefixed with `heroku-sys/`, so `php` becomes `heroku-sys/php`), which gets `composer install`ed using a custom Composer repository.

This `composer.json` gets written to `.heroku/php/` and is distinct from the application's `composer.json`. It only holds information on required platform packages.

The custom Composer repository, running off an S3 bucket, provides all of these packages; the Composer installer plugin in `support/installer/` handles extraction, activation, configuration etc.

### Custom platform packages and repositories

To use custom platform packages (either new ones, or modifications of existing ones), a new Composer repository has to be created (see main README for usage info). All the tooling in here is designed to work with S3, since it is reliable and cheap. The bucket permissions should be set up so that a public listing is allowed.

The folder `support/build` contains [Bob](http://github.com/kennethreitz/bob-builder) build formulae for all packages and their dependencies.

In `support/build/_util`, three scripts (`deploy.sh` to deploy a package, `mkrepo.sh` to (re-)generate a repo, and `sync.sh` to sync between repos) take care of most of the heavy lifting.

## Preparations

You may either build on a Heroku dyno, or locally using a Docker container. The instructions below use `heroku run`; simply replace them with the appropriate `docker run` call if you are using Docker.

The following environment variables are required:

- `WORKSPACE_DIR`, must be "`/app/support/build`"
- `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` with credentials for the S3 bucket
- `S3_BUCKET` with the name of the S3 bucket
- `S3_PREFIX` (either an empty string, or a prefix directory name **with a trailing, but no leading, slash**)
- `STACK` (currently, only "`cedar-14`" makes any sense)

The following environment variables are optional:

- `S3_REGION`, to be set to the AWS region name (e.g. "`s3-eu-west-1`") for any non-standard region, otherwise "`s3`" (for region "us-east-1")

### Build environment setup

#### Using Heroku

To get started, create a Python app (*Bob* is a Python application) on Heroku inside a clone of this repository, and set your S3 config vars:

    $ heroku create --buildpack heroku/python
    $ heroku config:set WORKSPACE_DIR=/app/support/build
    $ heroku config:set AWS_ACCESS_KEY_ID=<your_aws_key>
    $ heroku config:set AWS_SECRET_ACCESS_KEY=<your_aws_secret>
    $ heroku config:set S3_BUCKET=<your_s3_bucket_name>
    $ heroku config:set S3_PREFIX=<optional_s3_subfolder_to_upload_to_without_leading_but_with_trailing_slash>
    $ heroku config:set STACK=cedar-14
    $ git push heroku master
    $ heroku ps:scale web=0

#### Using Docker

Refer to the [README in `support/build/_docker/`](_docker/README.md) for setup instructions.

### Syncing an existing repository

Most builds will initially fail, because your bucket is empty and no formula dependencies can be pulled. You can sync from an official repository, e.g. `lang-php`, using a helper script - make sure you use the appropriate prefix (in this example, the default `dist-cedar-14-stable/` for the "cedar-14" stack):

    $ heroku run "support/build/_util/sync.sh your-bucket your-prefix/ lang-php dist-cedar-14-stable/"

*The `sync.sh` script takes destination bucket info as arguments first, then source bucket info*.

This only copies over "user-facing" items, but not library dependencies (e.g. `libraries/libmemcached`). You must copy those by hand using e.g. `s3cmd cp` if you want to use them; remember to specify `--acl-public`.

## Building a Package

At the very lowest level, `bob build` or `bob deploy` can be used to build a formula:

    $ heroku run bash
    Running `bash` attached to terminal... up, run.6880
    ~ $ bob build extensions/no-debug-non-zts-20121212/yourextension-1.2.3
    
    Fetching dependencies... found 1:
      - php-5.5.31
    Building formula extensions/no-debug-non-zts-20121212/yourextension-1.2.3
    ...

If that works, a `bob deploy` builds first and then uploads to your bucket (specify `--overwrite` to overwrite existing packages).

See the next section for important info about the manifest for your build; the *tl;dr* is: **do not use `bob build`, but `support/build/_util/deploy.sh`, to deploy a package**, because it will take care of manifest uploading:

    $ support/build/_util/deploy.sh extensions/no-debug-non-zts-20121212/yourextension-1.2.3

Sometimes, you need to deploy a prerequisite for another build, for instance a library, that needs no manifest. In that case, use `bob deploy`.

## About Manifests

After a `bob build` or `bob deploy`, you'll be prompted to upload a manifest (unless your build was for a library or other base dependency). It obviously only makes sense to perform this upload after a `bob deploy`.

To perform the deploy and the manifest upload in one step, **the `deploy.sh` utility in `support/build/_util/` should be used** instead of `bob build`:

    $ support/build/_util/deploy.sh extensions/no-debug-non-zts-20121212/yourextension-1.2.3

This will upload the manifest to the S3 bucket if the package build and deploy succeeded. Like `bob deploy`, this script accepts a `--overwrite` flag.

The manifest is a `composer.json` specific to your built package. All manifests of your bucket together need to be combined into a repository (see below).

### Manifest contents

A manifest looks roughly like this (example is for `ext-apcu/5.1.3` for PHP 7):

    {
    	"conflict": {
    		"heroku-sys/hhvm": "*"
    	},
    	"dist": {
    		"type": "heroku-sys-tar",
    		"url": "https://lang-php.s3.amazonaws.com/dist-cedar-14-stable/extensions/no-debug-non-zts-20151012/apcu-5.1.3.tar.gz"
    	},
    	"name": "heroku-sys/ext-apcu",
    	"require": {
    		"heroku-sys/cedar": "^14.0.0",
    		"heroku-sys/php": "7.0.*",
    		"heroku/installer-plugin": "^1.2.0"
    	},
    	"time": "2016-02-16 01:18:50",
    	"type": "heroku-sys-php-extension",
    	"version": "5.1.3"
    }

Package `name`s must be prefixed with "`heroku-sys/`". Possible `type`s are `heroku-sys-php`, `heroku-sys-hhvm`, `heroku-sys-php-extension` or `heroku-sys-webserver`. The `dist` type must be "`heroku-sys-tar`". If the package is a `heroku-sys-php-extension`, it's important to specify a `conflict` with "`heroku-sys/hhvm`".

The `require`d package `heroku/installer-plugin` will be available during install. Package `heroku-sys/cedar` is a virtual package `provide`d by the platform `composer.json` generated in `bin/compile` and has the right stack version; the selector for `heroku-sys/php` ensures that the package only applies to PHP 7.0.x.

### Manifest helpers

All formulae use the `manifest.py` helper to generate the information above. Use it for reliability! Take a look at the existing formulae and the script to get a feeling for how it works.

## About Repositories

The repository is a `packages.json` of all manifests, which can be used by Composer as a `packagist` repository type. See the main README for instructions on how to use such a repository on an application.

**Important: due to a limitation of Composer, extensions of identical version but for different PHP versions must be ordered within the repository in descending PHP version order, i.e. `ext-mongodb:1.1.2` for `php:7.0.*` must appear before `ext-mongodb:1.1.2` for `php:5.6.*`. Otherwise, deploys may select a lower PHP version than possible. The `mkrepo.sh` script takes care of this ordering.**

### (Re-)generating repositories

The normal flow is to run `support/build/_util/deploy.sh` first, and then to use `support/build/_util/mkrepo.sh` to re-generate the repo:

    $ support/build/_util/mkrepo.sh

This will generate `packages.json` and print upload instructions for `s3cmd`, or, if `--upload` is given, it will perform the upload right away.

Alternatively, `deploy.sh` can be called with `--publish` as the first argument, in which case `mkrepo.sh --upload` will be called after the package deploy and manifest upload was successful:

    $ support/build/_util/deploy.sh --publish php-6.0.0

### Syncing repositories

It is often desirable to have a bucket with two repositories under different prefixes, e.g. `cedar-14-develop/` and `cedar-14-stable/`. The "develop" bucket prefix would be set via `S3_PREFIX` on the Heroku app or Docker container, so all builds would always end up there.

After testing builds, the contents of that "develop" repository can then be synced to "stable" using `support/build/_util/mkrepo.sh`:

    $ support/build/_util/sync.sh my-bucket cedar-14-stable/ my-bucket cedar-14-develop/

The `sync.sh` script automatically detects additions, updates and removals based on manifests. It will also warn if the source `packages.json` is not up to date with its manifests, and prompt for confirmation before syncing.

The same can be used to sync from the official Heroku repository to the custom "develop" repository:

    $ support/build/_util/sync.sh my-bucket cedar-14-develop/ lang-php dist-cedar-14-master/

## Usage in applications

Please refer to [the instructions in the main README](../../README.md#custom-platform-repositories) for details on how to use a custom repository during application builds.

## Tips & Tricks

- To speed things up drastically during compilation, it'll usually be a good idea to `heroku run bash --size Performance-L`.
- All manifests generated by Bob formulas, by `support/build/_util/mkrepo.sh` and by `support/build/_util/sync.sh` use an S3 region of "s3" by default, so resulting URLs look like "`https://your-bucket.s3.amazonaws.com/your-prefix/...`". You can `heroku config:set S3_REGION` to change "s3" to another region such as "s3-eu-west-1".
- If any dependencies are not yet deployed, you need to deploy them first by e.g. running `bob deploy libraries/libmemcached`, or sync them with `sync.sh` or (for non-package dependencies) manually with `s3cmd cp --acl-public ...`.
