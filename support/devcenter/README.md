# Dev Center PHP Support Article and Changelog Generators

## PHP Support Generator

The `generate.php` tool will, given platform repository URLs as arguments, generate:

- the list of PHP runtimes, per stack
- the list of built-in extensions, per PHP runtime series
- the list of third-party extensions, per PHP runtime series
- the list of Composer versions, per stack
- the list of web servers, per stack

for inclusion in https://devcenter.heroku.com/articles/php-support

The extensions list is, where needed, annotated with footnotes that indicate if an extension isn't available on one or more stacks (this can happen e.g. when a required library doesn't exist on a stack).

The third-party extensions list will list major version series (e.g. 2.x and 3.x) separately unless they can be collapsed into a single row (e.g. because for PHP 7, they're all versions 1.x and for PHP 8, versions 2.x). Separate entries will be generated in a single cell if the versions should, for any reason, differ between stacks. Only the latest version of an x.0.0 series is listed.

For the "Composers" and web servers, only the latest release of each major version series is listed per stack.

### Invocation

First, `composer install` the dependencies.

By default, all sections will be generated:

```ShellSession
$ ./generate.php https://lang-php.s3.us-east-1.amazonaws.com/dist-heroku-{20,22,24-amd64}-stable/packages.json
```

You may also generate any of the five sections individually using the `--runtimes`, `--built-in-extensions`, `--third-party-extensions`, `--composers`, or `--webservers` options:

```ShellSession
$ ./generate.php --third-party-extensions https://lang-php.s3.us-east-1.amazonaws.com/dist-heroku-{20,22,24-amd64}-stable/packages.json
```

You'd usually pipe the output into e.g. `pbcopy` and then update the Dev Center article.

### Updating stacks and versions

To add a new stack or PHP runtime series, add them to the respective lists at the top of `generate.php`. Stacks or series that are no longer in use will not be output, but it's still a good idea to periodically remove EOL stacks or series from the list.

## Changelog Generator

The `changelog.php` tool expects the output from one or more `sync.sh` runs as input on STDIN.

It will then generate a list of new PHP releases, extensions, Composer versions, webservers, and other packages.

### Invocation

First, `composer install` the dependencies.

Assuming you ran a `sync.sh` job for two stacks (say, heroku-20 and heroku-22) and `tee`d the outputs into `sync-heroku-{20,22}.log`:

```ShellSession
cat `sync-heroku-{20,22}.log | ./changelog.php`
```
