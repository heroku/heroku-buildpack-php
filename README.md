# Heroku buildpack: PHP [![CI](https://github.com/heroku/heroku-buildpack-php/actions/workflows/ci.yml/badge.svg)](https://github.com/heroku/heroku-buildpack-php/actions/workflows/ci.yml)

![php](https://cloud.githubusercontent.com/assets/51578/13712789/9569dce4-e793-11e5-9147-1fe28dc802d6.png)

This is the official [Heroku buildpack](http://devcenter.heroku.com/articles/buildpacks) for PHP applications.

It uses Composer for dependency management, supports all recent versions of PHP as runtimes, and offers a choice of Apache2 or Nginx web servers.

## Usage

You'll need to use at least an empty `composer.json` in your application.

    $ echo '{}' > composer.json
    $ git add composer.json
    $ git commit -m "add composer.json for PHP app detection"

If you also have files from other frameworks or languages that could trigger another buildpack to detect your application as one of its own, e.g. a `package.json` which might cause your code to be detected as a Node.js application even if it is a PHP application, then you need to manually set your application to use this buildpack:

    $ heroku buildpacks:set heroku/php

This will use the officially published version. To use the default branch from GitHub instead:

    $ heroku buildpacks:set https://github.com/heroku/heroku-buildpack-php

Please refer to [Dev Center](https://devcenter.heroku.com/categories/php) for further usage instructions.

## Custom Platform Repositories

The buildpack uses Composer repositories to resolve platform (`php`, `ext-something`, ...) dependencies.

To use a custom Composer repository with additional or different platform packages, add the URL to its `packages.json` to the `HEROKU_PHP_PLATFORM_REPOSITORIES` config var:

    $ heroku config:set HEROKU_PHP_PLATFORM_REPOSITORIES="https://<your-bucket-name>.s3.<your-bucket-region>.amazonaws.com/heroku-20/packages.json"

To allow the use of multiple custom repositories, the config var may hold a list of multiple repository URLs, separated by a space character, in ascending order of precedence (meaning the last repository listed is handled first by Composer for package lookups).

**Please note that Heroku cannot provide support for issues related to custom platform repositories and packages.**

### Disabling the Default Repository

If the first entry in the list is "`-`" instead of a URL, the default platform repository is disabled entirely. This can be useful when testing development repositories, or to forcefully prevent the use of any packages from the default platform repository.

### Repository Priorities

It is possible to control [Composer Repository Priorities](https://getcomposer.org/doc/articles/repository-priorities.md) for custom platform repositories: whether Composer should

- treat a given repository as canonical;
- exclude specific packages from a repository;
- only allow specific packages from a repository.

These repository options (`canonical`, `exclude` and `only`) are controlled using the following query strings in the repository URL:

- `composer-repository-canonical` (`true` or `false`; defaults to `true`)
- `composer-repository-exclude` (comma-separated list of excluded package names)
- `composer-repository-only` (comma-separated list of allowed package names)

For example, the following config var will allow only packages `ext-igbinary` and `ext-redis` from `customrepo.com`; all other packages are looked up in the default repository:

    $ heroku config:set HEROKU_PHP_PLATFORM_REPOSITORIES="https://customrepo.com/packages.json?composer-repository-only=ext-igbinary,ext-redis"

### Building Custom Repositories

For instructions on how to build custom platform packages (and a repository to hold them), please refer to the instructions [further below](#custom-platform-packages-and-repositories).

## Development

The following information only applies if you're forking and hacking on this buildpack for your own purposes.

### Pull Requests

Please submit all pull requests against `develop` as the base branch.

### Custom Platform Packages and Repositories

Please refer to the [README in `support/build/`](support/build/README.md) for instructions.

