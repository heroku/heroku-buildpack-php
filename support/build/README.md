# Building Custom Platform Packages and Repositories

**Please note that Heroku cannot provide support for issues related to custom platform repositories and packages.**

## Introduction

### Background

PHP can be extended with so-called *extensions*, which are typically written in C and interface with the engine through specific APIs. These extensions most commonly provide bindings to native system libraries (e.g. `ext-amqp` for `libamqp`) to expose functionality to applications, but they can also hook into the PHP engine to enable certain features or insights (e.g. `ext-newrelic` for instrumentation).

Unlike language ecosystems such as Python or Ruby, PHP has no widely established and standardized method of compiling installing native extensions on a per-project basis during installation of an application's dependencies.

The [Composer](https://getcomposer.org) project is PHP's de-facto standard package manager. Through a `composer.json` file, applications express their dependencies; a dependency can be another user-land package, or a so-called *platform package*: a PHP runtime, or an extension. For user-land dependencies, the graph of requirements is reconciled at `composer update` time; platform package requirements are recorded separately. Together, they are written to the lock file, `composer.lock`, which enables reliable, stable installation of dependencies across environments.

If a given platform dependency cannot be fulfilled during a `composer install` attempt, the operation will fail. It is therefore necessary to provide the PHP runtime version that fulfills all package's requirements, and enable any required extensions (via the [`extension=…`](http://php.net/manual/en/ini.core.php#ini.extension) directive in `php.ini` or a [`.ini` scan dir](http://php.net/manual/en/configuration.file.php#configuration.file.scan) config) ahead of a `composer install` attempt.

On Heroku, when a PHP application is deployed, the `composer.lock` file is evaluated, and a new dependency graph that mirrors the application's platform dependencies (both direct ones and those required by other dependencies) is constructed. These requirements consist of special dependencies that contain actual platform packages, and this set of packages is then installed, before the regular installation of the application's dependencies (using a normal `composer install`) is performed.

### How Heroku installs platform dependencies

When an application is deployed, `bin/compile` extracts all platform dependencies from the application's `composer.lock` and constructs a new `composer.json`. This bulk of this process is performed in `bin/util/platform.php`. All platform requirements (for package `php`, `php-64bit`, and any package named `ext-…`) are extracted, their relative structure preserved, and all required package names are prefixed with "`heroku-sys/`" (so `php` becomes `heroku-sys/php`).

The resulting `composer.json` gets written to `.heroku/php/` and is distinct from the application's `composer.json`. It now only holds information on required platform packages, as well as a few other details such as the custom repository to use.

Assuming the following `composer.json` for an application:

    {
    	"require": {
    		"php": "~7.2",
    		"ext-mbstring": "*",
    		"mongodb/mongodb": "^1.4"
    	}
    }

The relevant parts of the corresponding `composer.lock` would look roughly like the following:

    {
    	"packages": [
    		{
    			"name": "mongodb/mongodb",
    			"version": "1.4.2",
    			…
    			"require": {
    				"ext-hash": "*",
    				"ext-json": "*",
    				"ext-mongodb": "^1.5.0",
    				"php": ">=5.5"
    			}
    		},
    	],
    	"platform": {
    		"php": "~7.2",
    		"ext-mbstring": "*",
    		"ext-pq": "*"
    	}
    }

From this, the buildpack would create a "platform package" `.heroku/php/composer.json` like the following, with the main [packagist.org](https://packagist.org) repository disabled, and a few custom repositories as well as static package definitions added:

    {
    	"provide": {
    		"heroku-sys/heroku": "18.2019.03.19"
    	},
    	"require": {
    		"composer.json/composer.lock": "dev-5f0dbc6293250a40259245759f113f27",
    		"mongodb/mongodb": "1.4.2"
    	},
    	"repositories": [
    		{
    			"packagist": false
    		},
    		{
    			"type": "path",
    			"url": "…/support/installer/",
    			"options": {
    				"symlink": false
    			}
    		},
    		{
    			"type": "composer",
    			"url": "https://lang-php.s3.amazonaws.com/dist-heroku-18-stable/"
    		},
    		{
    			"type": "package",
    			"package": [
    				{
    					"type": "metapackage",
    					"name": "mongodb/mongodb",
    					"version": "1.4.2",
    					"require": {
    						"heroku-sys/ext-hash": "*",
    						"heroku-sys/ext-json": "*",
    						"heroku-sys/ext-mongodb": "^1.5.0",
    						"heroku-sys/php": ">=5.5"
    					}
    				},
    				{
    					"type": "metapackage",
    					"name": "composer.json/composer.lock",
    					"version": "dev-5f0dbc6293250a40259245759f113f27",
    					"require": {
    						"heroku-sys/php": "~7.2",
    						"heroku-sys/ext-mbstring": "*",
    						"heroku-sys/ext-pq": "*"
    					}
    				}
    			]
    		}
    	]
    }

The structure of the originally required packages, such as `mongodb/mongodb`, is kept intact. This is done both to ensure that combinations requirements are taken into account the same way Composer does (two packages can have requirements for the same, say, `php` platform package), as well as to aid debugging: if, in the example above, `ext-mongodb` wasn't available on Heroku, then the error message from Composer would indicate that package `mongodb/mongodb` requires a non-existent package, and the user attempting the deploy would immediately understand why.

The requirements from the main `composer.json`, which in `composer.lock` are located in the `platform` key, are moved to their own meta-package named "`composer.json/composer.lock`"; this is again to ensure that these dependencies are honored correctly in combination will all the other requirements, and that users would get an immediately readable error message if a required package isn't available.

Also included, but omitted from the above example for brevity, are other packages such as the Nginx and Apache web servers, which users cannot directly specify as dependencies, but which are installed using the same mechanism as PHP or PHP extensions.

The two special repositories listed are the so-called *platform repository*, hosted here on S3, which holds all the required packages, and the *platform installer*, which is pulled in from a relative path location in the buildpack itself.

The custom Composer repository in the S3 bucket provides all of these magic `heroku-sys/…` packages; they are tarballs containing a binary build of PHP, or an extension, or a web server. Their metadata indicates their package type, download location, special installation hooks e.g. for activation of startup scripts, export instructions for e.g. `$PATH`, configuration files to copy on installation, and so forth.

The platform installer, implemented as a Heroku plugin, knows how to deal with all these details: it unpacks the binary tarballs, copies configuration files, prepares environment variable exports for `$PATH` so that binaries like `php` can be invoked.

In the example above, the `ext-mbstring` extension is, for example, not a separate package, but provided by the `php` package. Unlike the `ext-json` and `ext-hash` requirements from `mongodb/mongodb`, which are also bundled with PHP, but always enabled, the `ext-mbstring` extension is built as a shared extension, and must explicitly be loaded. The metadata information for the `php` package contains the details of all provided extensions, so the installer knows, based on a list of requirements and Composer's internal installer and dependency state, that a `php.ini` include that explicitly loads the `mbstring.so` library must be generated for the application to function.

The application also contains a requirement for the `ext-pq` PostgreSQL extension. This extension in turn internally requires `ext-raphf`. This dependency is contained in the platform repository that is used for installation, so the dependency graph will automatically contain this package, and it will be installed in the correct order: `ext-raphf` before `ext-pq`. As a result, the platform installer will generate the `extension=raphf.so` INI directive before the `extension=pq.so` INI directive, and PHP will start successfully. Were this not the case, PHP would fail to load `ext-pq` on startup, as `pq.so` could not find the `raphf.so` shared library it needs to function.

All these steps happen when the buildpack performs a simple `composer install` inside `.heroku/php/` - the generated `composer.json`, together with the repository and plugin information inside it, takes care of the rest.

## Usage in Applications

Please refer to [the instructions in the main README](../../README.md#custom-platform-repositories) for details on how to use a custom repository during application builds.

## Building Custom Platform Packages

### Overview

To use custom platform packages (either new ones, or modifications of existing ones), a new Composer repository has to be created (see [the instructions in the main README](../../README.md#custom-platform-repositories) for usage info). All the tooling in here is designed to work with S3, since it is reliable and cheap. The bucket permissions should be set up so that a public listing is allowed.

The folder `support/build` contains [Bob](http://github.com/kennethreitz/bob-builder) build formulae for all packages and their dependencies.

These build formulae can have dependencies (e.g. an extension formula depends on the correct version of PHP needed to build it, and maybe on a vendored library); Bob handles downloading of dependencies prior to a build, and it's the responsibility of a build formula to remove these dependencies again if they're not needed e.g. in between running `make` and `make install`.

The build formulae are also expected to generate a [manifest](#about-manifests), which is a `composer.json` containing all relevant information about a package.

In `support/build/_util`, three scripts (`deploy.sh` to deploy a package with its [manifest](#about-manifests), `mkrepo.sh` to (re-)generate a [repository](#about-repositories) from all existing manifests, and `sync.sh` to [sync between repos](#syncing-repositories)) take care of most of the heavy lifting. The directory is added to `$PATH` in `Dockerfile`, so the helpers can be invoked directly.

### Preparations

Packages for a platform repository are best built using a Docker container (either locally, or using on a platform like Heroku). The instructions below use `docker run…` locally.

Refer to the [README in `support/build/_docker/`](_docker/README.md) for setup instructions.

The following environment variables are required:

- `WORKSPACE_DIR`, must be "`/app/support/build`"
- `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` with credentials for the S3 bucket
- `S3_BUCKET` with the name of the S3 bucket to use for builds
- `S3_PREFIX` (just a slash, or a prefix directory name **with a trailing, but no leading, slash**)
- `STACK` (currently, only "`cedar-14`", "`heroku-16`" or "`heroku-18`" make any sense)

The following environment variables are highly recommended (see section *Understanding Upstream Buckets*):

- `UPSTREAM_S3_BUCKET` where dependencies are pulled from if they can't be found in `S3_BUCKET+S3_PREFIX`, should probably be set to "`lang-php`", the official Heroku bucket
- `UPSTREAM_S3_PREFIX`, where dependencies are pulled from if they can't be found in `S3_BUCKET+S3_PREFIX` should probably be set to
  - "`dist-cedar-14-stable/`", the official Heroku stable repository prefix for the [cedar-14 stack](https://devcenter.heroku.com/articles/stack).
  - "`dist-heroku-16-stable/`", the official Heroku stable repository prefix for the [heroku-16 stack](https://devcenter.heroku.com/articles/stack).
  - "`dist-heroku-18-stable/`", the official Heroku stable repository prefix for the [heroku-18 stack](https://devcenter.heroku.com/articles/stack).

The following environment variables are optional:

- `S3_REGION`, to be set to the AWS region name (e.g. "`s3-eu-west-1`") for any non-standard region, otherwise "`s3`" (for region "us-east-1")

#### Understanding Prefixes

It is recommended to use a prefix like "`dist-heroku-18-develop/`" for `$S3_PREFIX`. The contents of this prefix will act as a development repository, where all building happens. The `sync.sh` helper can later be used to synchronize to another prefix, e.g. "`dist-heroku-18-stable/`" that is used for production. For more info, see the [section on syncing repositories](#syncing-repositories) further below.

#### Understanding Upstream Buckets

If you want to, for example, host only a few PECL extensions in a custom repository, your bucket would still have to contain the build-time dependencies for those extensions - that's PHP in its various versions.

Due to the order in which Composer looks up packages from repositories, including PHP builds in your custom repositories may lead to those builds getting used on deploy, which is not what you want - you want to use Heroku's official PHP builds, but still have access to your custom-built extensions.

That's where the `UPSTREAM_S3_BUCKET` and `UPSTREAM_S3_PREFIX` env vars documented above come into play; you'll usually set them to "`lang-php`" and "`dist-heroku-18-stable/`", respectively (or whatever stack you're trying to build for).

That way, if your Bob formula for an extension contains e.g. this dependency declaration at the top:

    # Build Path: /app/.heroku/php
    # Build Deps: php-7.3.3

then on build, Bob will first look for "`php-7.3.3`" in your S3 bucket, and then fall back to pulling it from the upstream bucket. This frees you of the burden of hosting and maintaining unnecessary packages yourself.

### Building a Package

To verify a formula, `bob build` can be used to build it:

    $ docker run -ti --rm <yourimagetagname> bash
    ~ $ bob build extensions/no-debug-non-zts-20180731/yourextension-1.2.3
    
    Fetching dependencies... found 1:
      - php-7.3.3
    Building formula extensions/no-debug-non-zts-20180731/yourextension-1.2.3
    ...

If that works, a `bob deploy` would build it first, and then upload it to your bucket (you can specify `--overwrite` to overwrite existing packages).

However, that alone is not enough - the *manifest* needs to be in place as well, and using that manifest, you can then generate a Composer repository metadata file.

The next two sections contain important info about manifests and repositories; the *tl;dr* is: **do not use `bob deploy`, but `deploy.sh`, to deploy a package**, because it will take care of manifest uploading:

    ~ $ deploy.sh extensions/no-debug-non-zts-20180731/yourextension-1.2.3

In addition to an `--overwrite` option, the `deploy.sh` script also accepts a `--publish` option that will cause the package to immediately be published into the repository by [re-generating that repo](#re-generating-repositories). **This should be used with caution**, as several parallel `deploy.sh` invocations could result in a race condition when re-generating the repository.

## About Manifests

After a `bob build` or `bob deploy`, you'll be prompted to upload a manifest. It obviously only makes sense to perform this upload after a `bob deploy`.

To perform the deploy and the manifest upload in one step, **the `deploy.sh` utility (it's on `$PATH`) should be used instead of `bob deploy`**:

    ~ $ deploy.sh extensions/no-debug-non-zts-20180731/yourextension-1.2.3

This will upload the manifest to the S3 bucket if the package build and deploy succeeded. Like `bob deploy`, this script accepts a `--overwrite` flag.

The manifest is a `composer.json` specific to your built package, and it is **unrelated to Bob**, the utility that performs the builds. All manifests of your bucket together need to be combined into a [repository](#about-repositories).

All packages in the official Heroku S3 bucket use manifests, even for packages that are not exposed as part of the repository, such as library dependencies, the minimal PHP used for bootstrapping a build, or Composer.

### Manifest Contents

A manifest looks roughly like this (example is for `ext-apcu/5.1.17` for PHP 7.3 on stack `heroku-18`):

    {
    	"conflict": {
    		"heroku-sys/hhvm": "*"
    	},
    	"dist": {
    		"type": "heroku-sys-tar",
    		"url": "https://lang-php.s3.amazonaws.com/dist-heroku-18-stable/extensions/no-debug-non-zts-20180731/apcu-5.1.17.tar.gz"
    	},
    	"name": "heroku-sys/ext-apcu",
    	"require": {
    		"heroku-sys/heroku": "^18.0.0",
    		"heroku-sys/php": "7.3.*",
    		"heroku/installer-plugin": "^1.2.0"
    	},
    	"time": "2019-02-16 01:18:50",
    	"type": "heroku-sys-php-extension",
    	"version": "5.1.17"
    }

*Example: `curl -s https://lang-php.s3.amazonaws.com/dist-heroku-18-stable/packages.json | jq '[ .packages[][] | select(.type == "heroku-sys-php-extension" and .name == "heroku-sys/ext-apcu") ] | .[0]'`*

Package `name`s must be prefixed with "`heroku-sys/`". Possible `type`s are `heroku-sys-php`, `heroku-sys-hhvm`, `heroku-sys-php-extension` or `heroku-sys-webserver`. The `dist` type must be "`heroku-sys-tar`". If the package is a `heroku-sys-php-extension`, it's important to specify a `conflict` with "`heroku-sys/hhvm`".

The special package type `heroku-sys-php-package` is used for generic packages that should not be available to applications during app deploys (such as vendored libraries used to build PHP or an extension).

The `require`d package `heroku/installer-plugin` will be available during install. Package `heroku-sys/heroku` is a virtual package `provide`d by the platform `composer.json` generated in `bin/compile` and has the right stack version (either "`16`" or "`18`"); the selector for `heroku-sys/php` ensures that the package only applies to PHP 7.0.x.

### Manifest Helpers

All formulae use the `manifest.py` helper to generate the information above. **Use it for maximum reliability!** You can take a look at the existing formulae and the script to get a feeling for how it works.

For example, the Apache HTTPD web server is built roughly as follows:

    source $(dirname $BASH_SOURCE)/_util/include/manifest.sh
    curl … # download httpd
    ./configure --prefix="$1" …
    make && make install
    
    MANIFEST_REQUIRE="${MANIFEST_REQUIRE:-"{}"}"
    MANIFEST_CONFLICT="${MANIFEST_CONFLICT:-"{}"}"
    MANIFEST_REPLACE="${MANIFEST_REPLACE:-"{}"}"
    MANIFEST_PROVIDE="${MANIFEST_PROVIDE:-"{}"}"
    MANIFEST_EXTRA="${MANIFEST_EXTRA:-"{\"export\":\"bin/export.apache2.sh\",\"profile\":\"bin/profile.apache2.sh\"}"}"
    
    # this gets sourced after package install, so that the buildpack and following buildpacks can invoke
    cat > ${OUT_PREFIX}/bin/export.apache2.sh <<'EOF'
    export PATH="/app/.heroku/php/bin:/app/.heroku/php/sbin:$PATH"
    EOF
    # this gets sourced on dyno boot
    cat > ${OUT_PREFIX}/bin/profile.apache2.sh <<'EOF'
    export PATH="$HOME/.heroku/php/bin:$HOME/.heroku/php/sbin:$PATH"
    EOF
    
    python $(dirname $BASH_SOURCE)/_util/include/manifest.py "heroku-sys-webserver" "heroku-sys/${dep_name}" "$dep_version" "${dep_formula}.tar.gz" "$MANIFEST_REQUIRE" "$MANIFEST_CONFLICT" "$MANIFEST_REPLACE" "$MANIFEST_PROVIDE" "$MANIFEST_EXTRA" > $dep_manifest
    
    print_or_export_manifest_cmd "$(generate_manifest_cmd "$dep_manifest")"

In this example, after building the program from source and "installing" it to the right prefix, two scripts are added that take care of adding HTTPD's `bin/` and `sbin/` directories to `$PATH` during build (for following buildpacks to access), and during dyno boot (for the application to work at runtime).

Afterwards, `manifest.py` is passed several JSON objects as arguments for the various parts that make up the manifest. The `print_or_export_manifest_cmd` is then used to automatically either output instructions (when the formula is invoked via a `bob build` or `bob deploy`) on how to upload the manifest, or export the necessary manifest upload commands for automatic execution (when the formula is invoked via `deploy.sh`).

### Manifest Specification

The manifest for a package follows the [Composer package schema](https://getcomposer.org/doc/04-schema.md), with the following changes or additions.

#### Minimum Information

A package must at minimum expose the following details in its manifest:

- `name`
- `type`
- `dist` (with download type and URL)
- `time`
- `require`

The `require` key must contain dependencies on at least the following packages:

- `heroku/installer-plugin`, version 1.2.0 or newer (use version selector `^1.2.0`)

*Example: `curl -s https://lang-php.s3.amazonaws.com/dist-heroku-18-stable/packages.json | jq '[ .packages[][] | select(.type == "heroku-sys-php") ][0] | {require}'`*

If a package is built against a specific (or multiple) stacks, there must be a dependency on the following packages:

- `heroku-sys/heroku`, version "16" for `heroku-16` or version "18" for `heroku-18` (use version selectors `^16.0.0` or `^18.0.0`, or a valid Composer combination)

*Example: `curl -s https://lang-php.s3.amazonaws.com/dist-heroku-18-stable/packages.json | jq '[ .packages[][] | select(.type == "heroku-sys-php") ][0] | {require}'`*

If a package is of type `heroku-php-extension`, there must be a dependency on the following packages to ensure that the right PHP extension API is targeted during installs:

- `heroku-sys/php`, with major.minor version parts specified for the PHP version series in question (either as e.g. `7.3.*`, or as `~7.3.0`)

*Example: `curl -s https://lang-php.s3.amazonaws.com/dist-heroku-18-stable/packages.json | jq '[ .packages[][] | select(.type == "heroku-sys-php-extension") ][0] | {require}'`*

Additional dependencies can be expressed as well; for example, if an extension requires another extension at runtime, it may be listed in `require`, with its full `heroku-sys/ext-…` name and a suitable version (often "`*`").

*Example: `curl -s https://lang-php.s3.amazonaws.com/dist-heroku-18-stable/packages.json | jq '[ .packages[][] | select(.name == "heroku-sys/ext-pq") ][0] | {require}'`*

#### Package Name

The name of a package must begin with "`heroku-sys/`", and the part after this suffix must be the name Composer expects for the corresponding platform package. A PHP runtime package must thus be named "`heroku-sys/php`", and a "foobar" extension, known to Composer as "`ext-foobar`", must be named "`heroku-sys/ext-foobar`".

#### Package Type

The `type` of a package must be one of the following:

- 'heroku-sys-library', for a system library
- 'heroku-sys-php', for a PHP runtime
- 'heroku-sys-php-extension', for a PHP extension
- 'heroku-sys-webserver', for a web server

#### Dist Type and URL

The `dist` key must contain a struct with key `type` set to "`heroku-sys-tar`", and key `url` set to the `.tar.gz` tarball URL of the package.

*Example: `curl -s https://lang-php.s3.amazonaws.com/dist-heroku-18-stable/packages.json | jq '[ .packages[][] | select(.type == "heroku-sys-php") ][0] | {dist}'`*

#### Replaces

Composer packages may replace other packages. In the case of platform packages, this is useful mostly in case of a runtime. PHP is bundled with many extensions out of the box, so the manifest for the PHP package must indicate that it contains `ext-standard`, `ext-dom`, and so forth, and thus its manifest contains a long list of `heroku-sys/ext-…` entries under the `replace` key.

*Example: `curl -s https://lang-php.s3.amazonaws.com/dist-heroku-18-stable/packages.json | jq '[ .packages[][] | select(.type == "heroku-sys-php") ][0] | {replace}'`*

#### Extra: Config

A package of type `heroku-sys-php-extension` may contain a `config` key inside the `extra` struct holding a string with a config filename. If this key is not given, an automatic config that only loads the extension `.so` is generated. Otherwise, the given config file is used; it is then also responsible for loading the extension `.so` itself.

This feature can be used if an extension should have default configuration in place. For instance, when building an extension named "`foobar`" that you want some default INI settings to use, write a file named `$1/etc/php/conf.d/foobar.ini-dist` in your formula, with the following contents:

    extension=foobar.so
    foobar.some_default = different

If `extra`.`config` in the manifest is then set to "`etc/php/conf.d/memcached.ini-dist`", this config file will be used.

*Example: `curl -s https://lang-php.s3.amazonaws.com/dist-heroku-18-stable/packages.json | jq '[ .packages[][] | select(.name == "heroku-sys/ext-newrelic") ][0] | {extra: {config: .extra.config}}'`*

#### Extra: Export & Profile

Any package may generate shell scripts that are evaluated during app build, and during dyno startup, respectively. This is most commonly used for ensuring that built binaries are available on `$PATH` (for both cases), and for e.g. launching a sidecar process such as a proxy or agent (for the dyno startup case).

For example, a PHP runtime will want to make its `bin/` (for `php`) and `sbin/` (for `php-fpm`) available on `$PATH` both during a build (so that something like `composer install` can work at all during a build, or so a subsequent buildpack can invoke PHP), as well as on dyno startup (so that the application may function).

To achieve this, the formula would write a `bin/export.sh` with the following contents (the `/app` user directory must explicitly be given here):

    export PATH="/app/.heroku/php/bin:/app/.heroku/php/sbin:$PATH"

*Example: `curl -s https://lang-php.s3.amazonaws.com/dist-heroku-18-stable/packages.json | jq '[ .packages[][] | select(.type == "heroku-sys-webserver") ][0] | {extra: {export: .extra.export}}'`*

If the `extra`.`export` key in the manifest is then set to a string value of "`bin/export.sh`", the platform installer will ensure all packages have their export instructions executed after platform installation is complete.

In addition, a `bin/profile.sh` would also be necessary, with similar contents (but this time using `$HOME` instead of `/app`, for portability):

    export PATH="$HOME/.heroku/php/bin:$HOME/.heroku/php/sbin:$PATH"

*Example: `curl -s https://lang-php.s3.amazonaws.com/dist-heroku-18-stable/packages.json | jq '[ .packages[][] | select(.type == "heroku-sys-webserver") ][0] | {extra: {profile: .extra.profile}}'`*

If the `extra`.`profile` key in the manifest is then set to a string value of "`bin/profile.sh`", the platform installer will ensure that this script is executed, together with scripts from any other packages, during the startup of a dyno.

For most packages, the `export` key is never needed; the `profile` key is sometimes used to perform operations during dyno boot. For example, the `newrelic` extension uses it to start the `newrelic-daemon` background process.

*Example: `curl -s https://lang-php.s3.amazonaws.com/dist-heroku-18-stable/packages.json | jq '[ .packages[][] | select(.name == "heroku-sys/ext-newrelic") ][0] | {extra: {profile: .extra.profile}}'`*

#### Extra: Shared

As package of type `heroku-sys-php` may come bundled with a bunch of extensions, it must list these extensions in the `replace` section of its manifest. However, not all of these bundled extensions may be built into the engine, but instead may have been built as `shared`, meaning their `.so` needs to be loaded into the engine using an [`extension=…`](http://php.net/manual/en/ini.core.php#ini.extension) INI directive.

In order for the custom platform installer to know that an extension is built as shared, the names of all shared extensions (in full "`heroku-sys/ext-…`" format) must be listed inside the `extra`.`shared` struct as keys, each with a value of boolean `true`.

*Example: `curl -s https://lang-php.s3.amazonaws.com/dist-heroku-18-stable/packages.json | jq '[ .packages[][] | select(.type == "heroku-sys-php") ][0] | {extra: {shared: .extra.shared}}'`*

## About Repositories

The repository is a `packages.json` of all manifests, which can be used by Composer as a `packagist` repository type. See [Usage in Applications](#usage-in-applications) for instructions on how to use such a repository with an application.

**Important: due to a limitation of Composer, extensions of identical version but for different PHP versions must be ordered within the repository in descending PHP version order, i.e. `ext-mongodb:1.1.2` for `php:7.0.*` must appear before `ext-mongodb:1.1.2` for `php:5.6.*`. Otherwise, deploys may select a lower PHP version than possible. The `mkrepo.sh` script takes care of this ordering.**

### (Re-)generating Repositories

The normal flow is to run `deploy.sh` first to deploy one or more packages, and then to use `mkrepo.sh` to re-generate the repo:

    ~ $ mkrepo.sh --upload

This will generate `packages.json` and upload it right away, or, if the `--upload` is not given, print upload instructions for `s3cmd`.

Alternatively, `deploy.sh` can be called with `--publish` as the first argument, in which case `mkrepo.sh --upload` will be called after the package deploy and manifest upload was successful:

    ~ $ deploy.sh --publish php-6.0.0

**This should be used with caution, as several parallel `deploy.sh` invocations could result in a race condition when re-generating the repository.**

### Syncing Repositories

It is often desirable to have a bucket with two repositories under different prefixes, e.g. `dist-heroku-18-develop/` and `dist-heroku-18-stable/`, with the latter usually used by apps for deploys. The "develop" bucket prefix would be set via `S3_PREFIX` on the Heroku package builder app or Docker container, so all builds would always end up there.

After testing builds, the contents of that "develop" repository can then be synced to "stable" using `sync.sh`:

    ~ $ sync.sh my-bucket dist-heroku-18-stable/ my-bucket dist-heroku-18-develop/

*The `sync.sh` script takes destination bucket info as arguments first, then source bucket info*.

The `sync.sh` script automatically detects additions, updates and removals based on manifests. It will also warn if the source `packages.json` is not up to date with its manifests, and prompt for confirmation before syncing.

#### Syncing from Upstream

You will usually use an [Upstream Bucket](#understanding-upstream-buckets) to ensure that Bob will pull dependencies from Heroku's official bucket without having to worry about maintaining packages up the dependency tree, such as library or PHP prerequsites for an extension.

However, in rare circumstances, such as when you want to fully host all platform packages including PHP yourself and have the official repository disabled for your app, you either need to build all packages from scratch, or sync the Heroku builds from the official repository:

    ~ $ sync.sh $S3_BUCKET $S3_PREFIX $UPSTREAM_S3_BUCKET $UPSTREAM_S3_PREFIX

### Removing Packages

The `remove.sh` helper removes a package manifest and its tarball from a bucket, and re-generates the repository. It accepts one or more names of a JSON manifest file from the bucket (optionally without "`.composer.json`" suffix) as arguments:

    ~ $ remove.sh ext-imagick-3.3.0_php-5.5.composer.json ext-imagick-3.3.0_php-5.6.composer.json

Unless the `--no-publish` option is given, the repository will be re-generated immediately after removal. Otherwise, the manifests and tarballs would be removed, but the main repository would remain in place, pointing to non-existing packages, so usage of this flag is only recommended for debugging purposes or similar.

## Tips & Tricks

- All manifests generated by Bob formulas, by `mkrepo.sh` and by `sync.sh` use an S3 region of "s3" by default, so resulting URLs look like "`https://your-bucket.s3.amazonaws.com/your-prefix/...`". You can `heroku config:set S3_REGION` to change "s3" to another region such as "s3-eu-west-1".
- If any dependencies are not yet deployed, you need to deploy them first, or use `UPSTREAM_S3_BUCKET` and `UPSTREAM_S3_PREFIX` (recommended).
