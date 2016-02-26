# heroku-buildpack-php CHANGELOG

## v94 (2016-02-26)

### FIX

- No web servers get selected when a `composer.lock` is missing [David Zuelke]

## v93 (2016-02-26)

### ADD

- Support custom platform repositories via space separated `HEROKU_PHP_PLATFORM_REPOSITORIES` env var; leading "-" entry disables default repository [David Zuelke]

### CHG

- A `composer.phar` in the project root will no longer be aliased to `composer` on dyno startup [David Zuelke]
- Runtimes, extensions and web servers are now installed as fully self-contained Composer packages [David Zuelke]
- Perform boot script startup checks without loading unnecessary PHP configs or extensions [David Zuelke]
- ext-blackfire builds are now explicitly versioned (currently v1.9.1) [David Zuelke]
- Append `composer config bin-dir` to `$PATH` for runtime [David Zuelke]
- Check for lock file freshness using `composer validate` (#141) [David Zuelke]
- Change PHP `expose_php` to `off`, Apache `ServerTokens` to `Prod` and Nginx `server_tokens` to `off` for builds (#91, #92) [David Zuelke]
- Respect "provide", "replace" and "conflict" platform packages in dependencies and composer.json for platform package installs [David Zuelke]

### FIX

- Internal `php-min` symlink ends up in root of built apps [David Zuelke]
- Manifest for ext-apcu/4.0.10 does not declare ext-apc replacement [David Zuelke]
- Boot scripts exit with status 0 when given invalid flag as argument [David Zuelke]
- Manifest for ext-memcached/2.2.0 declares wrong PHP requirement for PHP 5.6 build [David Zuelke]
- Setting `NEW_RELIC_CONFIG_FILE` breaks HHVM builds (#149) [David Zuelke]

## v92 (2016-02-09)

### ADD

- ext-apcu/5.1.3 [David Zuelke]
- PHP/5.5.32 [David Zuelke]
- PHP/5.6.18 [David Zuelke]
- PHP/7.0.3 [David Zuelke]
- ext-phalcon/2.0.10 [David Zuelke]
- ext-blackfire for PHP 7 [David Zuelke]

### CHG

- Refactor and improve build manifest helpers, add bucket sync tooling [David Zuelke]
- Use Bob 0.0.7 for builds [David Zuelke]

### FIX

- PHP 7 extension formulae use wrong API version in folder name [David Zuelke]
- Composer build formula depends on removed PHP formula [Stefan Siegl]

## v91 (2016-01-08)

### ADD

- ext-phalcon/2.0.9 [David Zuelke]
- PHP/7.0.2 [David Zuelke]
- PHP/5.6.17 [David Zuelke]
- PHP/5.5.31 [David Zuelke]
- ext-apcu/5.1.2 [David Zuelke]
- ext-mongodb/1.1.2 [David Zuelke]
- ext-oauth/2.0.0 [David Zuelke]

## v90 (2015-12-18)

### ADD

- PHP/7.0.1 [David Zuelke]

### CHG

- Double default INI setting values for `opcache.memory_consumption`, `opcache.interned_strings_buffer` and `opcache.max_accelerated_files` [David Zuelke]

## v89 (2015-12-15)

### FIX

- HHVM builds failing when trying to install New Relic or Blackfire [David Zuelke]

## v88 (2015-12-15)

### CHG

- Big loud warnings if `composer.lock` is outdated (or even broken) [David Zuelke]
- Auto-install `ext-blackfire` and `ext-newrelic` at the very end of the build to avoid them instrumenting build steps or cluttering output with startup messages [David Zuelke]

### FIX

- Buildpack does not export PATH for multi-buildpack usage [David Zuelke]
- Composer limitation leads to lower than possible PHP versions getting resolved [David Zuelke]
- `lib-` platform package requirements may prevent dependency resolution [David Zuelke]
- Invalid/broken `composer.lock` produces confusing error message [David Zuelke]

## v87 (2015-12-11)

### CHG

- Further improve error information on failed system package install [David Zuelke]
- Notice if implicit version selection based on dependencies' requirements is made [David Zuelke]

### FIX

- "`|`" operators in `composer.lock` platform package requirements break system package dependency resolution [David Zuelke]
- Notice about missing runtime version selector does not show up in all cases [David Zuelke]

## v86 (2015-12-10)

### ADD

- PHP/7.0.0 [David Zuelke]
- PHP/5.6.16 [David Zuelke]
- ext-apcu/4.0.10 [David Zuelke]
- ext-mongo/1.6.12 [David Zuelke]
- ext-imagick/3.3.0 [David Zuelke]
- ext-blackfire/1.7.0 [David Zuelke]

### CHG

- Rewrite most of the build process; system packages are now installed using a custom Composer installer and Composer repository [David Zuelke]

## v83 (2015-11-16)

### ADD

- Composer/1.0.0-alpha11 [David Zuelke]
- PHP/7.0.0RC7 [David Zuelke]

### CHG

- Improve Composer vendor and bin dir detection in build sources [David Zuelke]
- Deprecate concurrent installs of HHVM and PHP [David Zuelke]
- Start New Relic daemon manually on Dyno boot to ensure correct behavior with non web PHP programs [David Zuelke]

### FIX

- Wrong Apache dist URL in support/build [David Zuelke]
- Build failure if `heroku-*-*` boot scripts are committed to Git in Composer bin dir [David Zuelke]
- Broken signal handling in boot scripts on Linux [David Zuelke]

## v82 (2015-10-31)

### CHG

- Downgrade Apache 2.4.17 to Apache 2.4.16 due to `REDIRECT_URL` regression [David Zuelke]

## v81 (2015-10-30)

### ADD

- PHP/7.0.0RC6 [David Zuelke]
- PHP/5.6.15 [David Zuelke]

## v80 (2015-10-15)

### ADD

- Nginx/1.8.0 [David Zuelke]
- Apache/2.4.17 [David Zuelke]
- PHP/7.0.0RC5 [David Zuelke]

### CHG

- Use system default php.ini config instead of buildpacks' if no custom config given [David Zuelke]

## v79 (2015-10-08)

### CHG

- Enable Apache modules `ssl_module` and `mod_proxy_html` (with `mod_xml2enc` dependency) by default [David Zuelke]

## v78 (2015-10-01)

### ADD

- PHP/7.0.0RC4 [David Zuelke]
- PHP/5.5.30 [David Zuelke]
- PHP/5.6.14 [David Zuelke]

## v77 (2015-09-17)

### ADD

- PHP/7.0.0RC3 [David Zuelke]

## v76 (2015-09-08)

### ADD

- ext-mongo/1.6.11 [David Zuelke]
- PHP/7.0.0RC2 [David Zuelke]
- PHP/5.5.29 [David Zuelke]
- PHP/5.6.13 [David Zuelke]

## v75 (2015-08-21)

### FIX

- Prevent potential (benign) Python notice during builds

## v74 (2015-08-21)

### FIX

- Warning about missing composer.lock is thrown incorrectly for some composer.json files

## v72 (2015-08-21)

### ADD

- PHP/5.6.12 [David Zuelke]
- PHP/5.5.28 [David Zuelke]
- ext-newrelic/4.23.4.113 [David Zuelke]
- PHP/7.0.0RC1 [David Zuelke]
- Support custom `composer.json`/`composer.lock` file names via `$COMPOSER` env var [David Zuelke]

### CHG

- A composer.lock is now required if there is any entry in the "require" section of composer.json [David Zuelke]

## v71 (2015-07-14)

### ADD

- ext-newrelic/4.23.1.107 [David Zuelke]

### FIX

- Apache `mod_proxy_fgci`'s "disablereuse=off" config flag causes intermittent blank pages with HTTPD 2.4.11+ [David Zuelke]
- Applications on cedar-10 can select non-existing PHP 7.0.0beta1 package via composer.json [David Zuelke]

## v70 (2015-07-10)

### ADD

- PHP/7.0.0beta1 [David Zuelke]
- PHP/5.6.11 [David Zuelke]
- PHP/5.5.27 [David Zuelke]
- ext-newrelic/4.23.0.102 [David Zuelke]
- ext-mongo/1.6.10 [David Zuelke]
- Support auto-tuning for IX dyno type [David Zuelke]

### CHG

- Warn about missing extensions for "blackfire" and "newrelic" add-ons during startup [David Zuelke]

## v69 (2015-06-12)

### ADD

- PHP/5.5.26 [David Zuelke]
- PHP/5.6.10 [David Zuelke]
- ext-newrelic/4.22.0.99 [David Zuelke]
- ext-mongo/1.6.9 [David Zuelke]

## v68 (2015-05-18)

### ADD

- PHP/5.6.9 [David Zuelke]
- PHP/5.5.25 [David Zuelke]
- ext-newrelic/4.21.0.97 [David Zuelke]
- ext-mongo/1.6.8 [David Zuelke]

### CHG

- Use Composer/1.0.0alpha10 [David Zuelke]
- Link only `.heroku/php/` subfolder and not all of `.heroku/` during compile to prevent potential collisions in multi BP scenarios [David Zuelke]

### FIX

- Typo in log messages [Christophe Coevoet]
- Newrelic 4.21 agent startup complaining about missing pidfile location config [David Zuelke]

## v67 (2015-03-24)

### ADD

- ext-mongo/1.6.6 [David Zuelke]
- PHP/5.6.7 [David Zuelke]
- PHP/5.5.23 [David Zuelke]

### CHG

- Don't run composer install for empty composer.json [David Zuelke]
- Unset GIT_DIR at beginning of compile [David Zuelke]

## v66 (2015-03-05)

### ADD

- ext-newrelic/4.19.0.90 [David Zuelke]

## v65 (2015-03-03)

### ADD

- ext-redis/2.2.7 [David Zuelke]
- ext-mongo/1.6.4 [David Zuelke]
- HHVM/3.3.4 [David Zuelke]

### CHG

- Composer uses stderr now for most output, indent that accordingly [David Zuelke]

## v64 (2015-02-19)

### ADD

- HHVM/3.5.1 [David Zuelke]
- PHP/5.6.6 [David Zuelke]
- PHP/5.5.22 [David Zuelke]
- ext-newrelic/4.18.0.89 [David Zuelke]
- ext-mongo/1.6.3 [David Zuelke]

## v63 (2015-02-11)

### ADD

- ext-mongo/1.6.2 [David Zuelke]

### CHG

- Tweak auto-tuning messages (tag: v63) [David Zuelke]
- Move 'booting...' message to after startup has finished [David Zuelke]
- Ignore SIGINT when running under foreman etc to ensure clean shutdown [David Zuelke]
- Prevent redundant messages when loading HHVM configs [David Zuelke]
- Echo "running workers..." message to stderr on boot [David Zuelke]

### FIX

- Incorrect 'child 123 said into stderr' removal for lines that are deemed to long by FPM and cut off using a terminating '...' sequence instead of closing double quotes [David Zuelke]

## v62 (2015-02-04)

### FIX

- Broken PHP memlimit check [David Zuelke]

## v61 (2015-02-04)

### CHG

- Port autotuning to HHVM-Nginx [David Zuelke]

### FIX

- Workaround for Composer's complaining about outdated version warnings on stdout instead of stderr, breaking calls in a few places under certain circumstances [David Zuelke]

## v60 (2015-02-04)

### ADD

- Auto-tune number of workers based on dyno size and configured memory limit [David Zuelke]

## v59 (2015-01-29)

### ADD

- ext-mongo/1.6.0 (tag: v59) [David Zuelke]

### CHG

- Improvements to INI handling for HHVM, including new `-I` switch to allow passing additional INI files at boot [David Zuelke]
- Massively improved subprocess and signal handling in boot scripts [David Zuelke]

## v58 (2015-01-26)

### ADD

- HHVM/3.5.0 [David Zuelke]
- PHP/5.6.5 [David Zuelke]
- PHP/5.5.21 [David Zuelke]

## v57 (2015-01-19)

### CHG

- Update to Composer dev version for `^` selector support [David Zuelke]

## v56 (2015-01-13)

### ADD

- ext/oauth 1.2.3 [David Zuelke]
- HHVM/3.3.3 [David Zuelke]
- Run 'composer compile' for custom scripts at the end of deploy [David Zuelke]

## v55 (2015-01-07)

### FIX

- Standard logs have the wrong $PORT in the file name if the -p option is used in boot scripts [David Zuelke]

## v54 (2015-01-05)

### ADD

- ext-newrelic/4.17.0.83 [David Zuelke]

### CHG

- Auto-set and follow (but not enable, for now) the FPM slowlog [David Zuelke]
