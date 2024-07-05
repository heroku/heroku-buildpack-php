# Changelog

## [Unreleased]


## [v254] - 2024-07-05

### ADD

- PHP/8.2.21 [David Zuelke]
- PHP/8.3.9 [David Zuelke]
- ext-newrelic/10.22.0.12 [David Zuelke]
- ext-blackfire/1.92.18 [David Zuelke]

### CHG

- Sync Nginx `mime.types` config with upstream to add `application/wasm` for `.wasm` and `image/avif` for `.avif` files (#738) [David Zuelke]
- Add MIME type `text/javascript` for `.mjs` files to Nginx config as per RFC 9239; `application/javascript` remains for `.js` from upstream default `mime.types` (#737) [David Zuelke]
- Apache/2.4.61 [David Zuelke]
- Blackfire/2.28.7 [David Zuelke]

## [v253] - 2024-06-13

### ADD

- PHP/8.1.29 [David Zuelke]
- PHP/8.2.20 [David Zuelke]
- PHP/8.3.8 [David Zuelke]
- ext-newrelic/10.21.0.11 [David Zuelke]
- ext-mongodb/1.19.2 [David Zuelke]

### CHG

- Nginx/1.26.1 [David Zuelke]
- Blackfire/2.28.4 [David Zuelke]
- Composer/2.2.24 [David Zuelke]
- Composer/2.7.7 [David Zuelke]

## [v252] - 2024-05-31

### ADD

- Support heroku-24 [David Zuelke]
- Build arm64 binaries for heroku-24+ [David Zuelke]

### CHG

- Use PHP 8.3 for bootstrapping [David Zuelke]
- librdkafka/2.4.0 (for heroku-24+ only) [David Zuelke]

## [v251] - 2024-05-30

### ADD

- PHP/8.3.7 [David Zuelke]

## [v250] - 2024-05-29

### ADD

- PHP/8.1.28 [David Zuelke]
- PHP/8.2.19 [David Zuelke]
- PHP/8.3.6 [David Zuelke]
- ext-newrelic/10.20.0.10 [David Zuelke]
- ext-phalcon/5.7.0 [David Zuelke]
- ext-blackfire/1.92.17 [David Zuelke]
- ext-mongodb/1.19.1 [David Zuelke]

### CHG

- Composer/2.7.6 [David Zuelke]
- Blackfire/2.28.3 [David Zuelke]

## [v249] - 2024-04-12

### ADD

- PHP/8.2.18 [David Zuelke]
- PHP/8.3.5 [David Zuelke]
- ext-mongodb/1.18.1 [David Zuelke]

### CHG

- Blackfire/2.26.4 [David Zuelke]
- Apache/2.4.59 [David Zuelke]

## [v248] - 2024-03-28

### ADD

- PHP/8.2.17 [David Zuelke]
- PHP/8.3.4 [David Zuelke]
- ext-phalcon/5.6.2 [David Zuelke]
- ext-newrelic/10.19.0.9 [David Zuelke]
- ext-mongodb/1.18.0 [David Zuelke]
- ext-blackfire/1.92.13 [David Zuelke]

### CHG

- Blackfire/2.26.1 [David Zuelke]
- Composer/2.7.2 [David Zuelke]

## [v247] - 2024-02-29

### ADD

- PHP/8.2.16 [David Zuelke]
- PHP/8.3.3 [David Zuelke]
- ext-event/3.1.3 [David Zuelke]
- ext-pq/2.2.3 [David Zuelke]
- ext-phalcon/5.6.1 [David Zuelke]
- ext-blackfire/1.92.10 [David Zuelke]
- ext-newrelic/10.17.0.7 [David Zuelke]

### CHG

- Improve handling of concurrent or unknown signals in boot scripts [David Zuelke]
- Raise curl connection timeout threshold from 5 to 10 seconds [David Zuelke]
- Blackfire/2.25.0 [David Zuelke]
- Composer/2.2.23 [David Zuelke]
- Composer/2.7.1 [David Zuelke]

## [v246] - 2024-02-09

### FIX

- `WEB_CONCURRENCY` auto-tuning may warn about an invalid suffix for certain available memory values [David Zuelke]

## [v245] - 2024-02-09

### ADD

- Boot scripts now have a `--test`/`-t` option to test PHP-FPM and web server configs and then exit. Can be repeated to dump configs for either or both, see `--help` for details. [David Zuelke]

### CHG

- New formula for determining number of PHP-FPM worker processes: `min(floor(RAM_AVAIL / memory_limit), ceil(log_2(RAM_AVAIL / CALC_BASE)) * NUM_CORES * 2 * (CALC_BASE / memory_limit)` [`CALC_BASE` is currently `128M`] - same results for current Heroku dyno types, but "softer" scaling of worker count on containers with a lot of RAM [David Zuelke]

### FIX

- PHP `memory_limit` in `.user.ini` does not override PHP-FPM `php_value` for `$WEB_CONCURRENCY` calculation [David Zuelke]
- PHP-FPM `request_terminate_timeout` may have no effect [David Zuelke]

## [v244] - 2024-01-24

### ADD

- PHP/8.3.2 [David Zuelke]
- PHP/8.2.15 [David Zuelke]
- ext-event/3.1.1 [David Zuelke]
- ext-phalcon/5.6.0 [David Zuelke]
- ext-blackfire/1.92.8 [David Zuelke]
- ext-amqp/2.1.2 [David Zuelke]

### CHG

- blackfire/2.24.4 [David Zuelke]

## [v243] - 2023-12-21

### ADD

- PHP/8.1.27 [David Zuelke]
- PHP/8.2.14 [David Zuelke]
- PHP/8.3.1 [David Zuelke]
- ext-blackfire/1.92.4 [David Zuelke]
- ext-mongodb/1.17.2 [David Zuelke]
- ext-newrelic/10.15.0.4 [David Zuelke]

### CHG

- Composer/2.6.6 [David Zuelke]
- blackfire/2.24.2 [David Zuelke]

## [v242] - 2023-12-07

### ADD

- PHP/8.3.0 [David Zuelke]

## [v241] - 2023-11-29

- PHP/8.1.26 [David Zuelke]
- PHP/8.2.13 [David Zuelke]
- ext-apcu/5.1.23 [David Zuelke]
- ext-mongodb/1.17.0 [David Zuelke]
- ext-newrelic/10.14.0.3 [David Zuelke]
- ext-blackfire/1.92.1 [David Zuelke]

## [v240] - 2023-10-27

### ADD

- PHP/8.1.25 [David Zuelke]
- PHP/8.2.12 [David Zuelke]
- ext-newrelic/10.13.0.2 [David Zuelke]
- ext-amqp/2.1.1 [David Zuelke]
- ext-redis/6.0.2 [David Zuelke]
- ext-phalcon/5.4.0 [David Zuelke]

### CHG

- Exclude `support/{build,devcenter}/` from the packaged buildpack [Ed Morley]
- Composer/2.6.5 [David Zuelke]
- Apache/2.4.58 [David Zuelke]
- blackfire/2.23.0 [David Zuelke]

## [v239] - 2023-09-30

### ADD

- PHP/8.1.24 [David Zuelke]
- PHP/8.2.11 [David Zuelke]
- ext-amqp/2.1.0 [David Zuelke]
- ext-phalcon/5.3.1 [David Zuelke]
- ext-newrelic/10.12.0.1 [David Zuelke]
- ext-redis/6.0.1 (with lz4, lzf, zstd support enabled) [David Zuelke]
- ext-blackfire/1.90.0 [David Zuelke]
- Composer/1.10.27 [David Zuelke]
- Composer/2.2.22 [David Zuelke]
- Composer/2.6.4 [David Zuelke]

### CHG

- blackfire/2.22.0 [David Zuelke]

## [v238] - 2023-08-31

### ADD

- ext-phalcon/5.3.0 [David Zuelke]
- ext-mongodb/1.16.2 [David Zuelke]
- ext-amqp/2.0.0 [David Zuelke]
- PHP/8.1.23 [David Zuelke]
- PHP/8.2.10 [David Zuelke]

### CHG

- Import telemetry helper shell functions previously vendored from 'lang-common' S3 bucket [David Zuelke]
- blackfire/2.21.0 [David Zuelke]

## [v237] - 2023-08-04

### ADD

- PHP/8.0.30 [David Zuelke]
- PHP/8.1.22 [David Zuelke]
- PHP/8.2.9 [David Zuelke]
- ext-phalcon/5.2.3 [David Zuelke]

### CHG

- blackfire/2.19.0 [David Zuelke]

## [v236] - 2023-07-18

### ADD

- PHP/8.1.21 [David Zuelke]
- PHP/8.2.8 [David Zuelke]
- ext-blackfire/1.88.1 [David Zuelke]
- ext-mongodb/1.16.1 [David Zuelke]
- ext-newrelic/10.11.0.3 [David Zuelke]
- ext-phalcon/5.2.2 [David Zuelke]
- ext-pq/2.2.2 [David Zuelke]

### CHG

- blackfire/2.17.0 [David Zuelke]
- Composer/2.5.8 [David Zuelke]

### FIX

- PHP binary build formula uses outdated signature for Composer installer (#641) [David Zuelke]

## [v235] - 2023-06-09

### ADD

- PHP/8.0.29 [David Zuelke]
- PHP/8.1.20 [David Zuelke]
- PHP/8.2.7 [David Zuelke]
- ext-newrelic/10.10.0.1 [David Zuelke]

## [v234] - 2023-05-25

### ADD

- PHP/8.1.19 [David Zuelke]
- PHP/8.2.6 [David Zuelke]
- ext-blackfire/1.87.2 [David Zuelke]
- ext-mongodb/1.15.3 [David Zuelke]

### CHG

- Drop support for the heroku-18 stack [David Zuelke]
- Drop support for PHP 7.1 and PHP 7.2 [David Zuelke]
- blackfire/2.16.1 [David Zuelke]
- Composer/2.5.7 [David Zuelke]

## [v233] - 2023-04-14

### ADD

- PHP/8.1.18 [David Zuelke]
- PHP/8.2.5 [David Zuelke]
- ext-newrelic/10.9.0.324 [David Zuelke]
- ext-blackfire/1.86.6 [David Zuelke]

### CHG

- Do not block access to /.well-known/ in Nginx config [Christophe Coevoet, David Zuelke]
- Do not block access to /.well-known/ in Apache HTTPD config [Christophe Coevoet, David Zuelke]
- Apache/2.4.57 [David Zuelke]
- Nginx/1.24.0 [David Zuelke]
- blackfire/2.15.0 [David Zuelke]

## [v232] - 2023-03-27

### ADD

- PHP/8.1.17 [David Zuelke]
- PHP/8.2.4 [David Zuelke]
- ext-blackfire/1.86.5 [David Zuelke]
- ext-mongodb/1.15.1 [David Zuelke]
- ext-newrelic/10.8.0.323 [David Zuelke]
- ext-phalcon/5.2.1 [David Zuelke]

### CHG

- Apache/2.4.56 [David Zuelke]
- blackfire/2.14.0 [David Zuelke]
- Composer/2.5.5 [David Zuelke]

## [v231] - 2023-02-14

### ADD

- ext-newrelic/10.6.0.318 [David Zuelke]
- PHP/8.0.28 [David Zuelke]
- PHP/8.2.3 [David Zuelke]
- PHP/8.1.16 [David Zuelke]
- ext-blackfire/1.86.4 [David Zuelke]

### CHG

- Composer/2.2.20 [David Zuelke]
- Composer/2.5.3 [David Zuelke]

## [v230] - 2023-02-07

### ADD

- PHP/8.1.15 [David Zuelke]
- PHP/8.2.2 [David Zuelke]

### CHG

- Use non-legacy structure for platform packages Composer repository [David Zuelke]
- Composer/2.2.19 [David Zuelke]
- Composer/2.5.2 [David Zuelke]

### FIX

- `autotune.php` throws deprecation warning on PHP 8.2 (#615) [Simo Heinonen]

## [v229] - 2023-01-25

### ADD

- PHP/8.2.1 [David Zuelke]

## [v228] - 2023-01-25

### ADD

- ext-mongodb/1.15.0 [David Zuelke]
- PHP/8.0.27 [David Zuelke]
- PHP/8.1.14 [David Zuelke]
- ext-phalcon/5.1.4 [David Zuelke]
- ext-blackfire/1.86.3 [David Zuelke]
- ext-newrelic/10.5.0.317 [David Zuelke]

### CHG

- Build Nginx with `--with-http_auth_request_module` (#455) [David Zuelke]
- Build Nginx with `--with-http_stub_status_module` (#598) [David Zuelke]
- blackfire/2.13.2 [David Zuelke]
- Composer/2.5.1 [David Zuelke]
- Apache/2.4.55 [David Zuelke]

## [v227] - 2022-11-03

### ADD

- PHP/7.4.33 [David Zuelke]
- ext-newrelic/10.3.0.315 [David Zuelke]
- ext-phalcon/5.1.0 [David Zuelke]

### CHG

- Fail if platform packages dir is part of app source [David Zuelke]

## [v226] - 2022-10-27

### ADD

- PHP/8.0.25 [David Zuelke]
- PHP/8.1.12 [David Zuelke]
- ext-blackfire/1.84.0 [David Zuelke]
- ext-mongodb/1.14.2 [David Zuelke]
- ext-phalcon/5.0.5 [David Zuelke]

### CHG

- blackfire/2.13.0 [David Zuelke]
- Composer/2.4.4 [David Zuelke]
- Nginx/1.22.1 [David Zuelke]

## [v225] - 2022-10-05

### ADD

- PHP/7.4.32 [David Zuelke]
- PHP/8.0.24 [David Zuelke]
- PHP/8.1.11 [David Zuelke]
- ext-blackfire/1.83.0 [David Zuelke]
- ext-mongodb/1.14.1 [David Zuelke]
- ext-newrelic/10.2.0.314 [David Zuelke]
- ext-phalcon/5.0.2 [David Zuelke]

### CHG

- Composer/2.4.2 [David Zuelke]
- blackfire/2.12.0 [David Zuelke]

## [v224] - 2022-09-05

### ADD

- ext-blackfire/1.81.0 [David Zuelke]
- ext-phalcon/5.0.0RC4 [David Zuelke]
- PHP/8.0.23 [David Zuelke]
- PHP/8.1.10 [David Zuelke]

### CHG

- Composer/2.4.1 [David Zuelke]
- Composer/2.2.18 [David Zuelke]
- blackfire/2.10.1 [David Zuelke]

## [v223] - 2022-08-04

### ADD

- ext-phalcon/5.0.0RC3 [David Zuelke]
- PHP/8.0.22 [David Zuelke]
- PHP/8.1.9 [David Zuelke]
- ext-mongodb/1.14.0 [David Zuelke]
- ext-blackfire/1.80.0 [David Zuelke]

### CHG

- Composer/2.2.17 [David Zuelke]
- Composer/2.3.10 [David Zuelke]
- librdkafka/1.9.2 [David Zuelke]

## [v222] - 2022-07-07

### ADD

- PHP/8.0.21 [David Zuelke]
- PHP/8.1.8 [David Zuelke]
- ext-blackfire/1.79.0 [David Zuelke]
- ext-newrelic/10.0.0.312 [David Zuelke]
- ext-rdkafka/6.0.3 [David Zuelke]

### CHG

- Composer/2.2.16 [David Zuelke]
- Composer/2.3.9 [David Zuelke]
- Apache/2.4.54 [David Zuelke]
- Nginx/1.22.0 [David Zuelke]
- librdkafka/1.9.1 [David Zuelke]

## [v221] - 2022-07-01

### CHG

- Adjust curl connection timeout handling [Ed Morley]
- Composer/2.2.15 [David Zuelke]
- Composer/2.3.8 [David Zuelke]

## [v220] - 2022-06-15

### CHG

- Use recommended AWS regional S3 domain for interactions with platform repository buckets [Ed Morley, David Zuelke]

## [v219] - 2022-06-09

### ADD

- PHP/7.4.30 [David Zuelke]
- PHP/8.0.20 [David Zuelke]
- PHP/8.1.7 [David Zuelke]
- ext-event/3.0.8 [David Zuelke]

### CHG

- Composer/2.2.14 [David Zuelke]
- Composer/2.3.7 [David Zuelke]
- blackfire/2.10.0 [David Zuelke]

## [v218] - 2022-05-27

### ADD

- Support for heroku-22 stack [David Zuelke]

## [v217] - 2022-05-18

### ADD

- PHP/8.0.19 [David Zuelke]
- PHP/8.1.6 [David Zuelke]
- ext-newrelic/9.21.0.311 [David Zuelke]
- ext-blackfire/1.78.0 [David Zuelke]

### CHG

- blackfire/2.9.0 [David Zuelke]

## [v216] - 2022-04-14

### ADD

- PHP/7.4.29 [David Zuelke]
- PHP/8.0.18 [David Zuelke]
- PHP/8.1.5 [David Zuelke]
- ext-blackfire/1.76.0 [David Zuelke]
- ext-memcached/3.2.0 [David Zuelke]
- ext-mongodb/1.13.0 [David Zuelke]

### CHG

- Composer/1.10.26 [David Zuelke]
- Composer/2.2.12 [David Zuelke]
- Composer/2.3.5 [David Zuelke]
- blackfire/2.7.1 [David Zuelke]

## [v215] - 2022-04-08

### CHG

- Composer/2.3.4 [David Zuelke]

## [v214] - 2022-04-04

### ADD

- Composer/2.3.3 [David Zuelke]

### CHG

- Composer/2.2.11 [David Zuelke]

## [v213] - 2022-03-17

### ADD

- PHP/8.0.17 [David Zuelke]
- PHP/8.1.4 [David Zuelke]
- ext-blackfire/1.75.0 [David Zuelke]
- ext-mongodb/1.12.1 [David Zuelke]
- ext-newrelic/9.20.0.310 [David Zuelke]
- ext-rdkafka/6.0.1 [David Zuelke]

### CHG

- Apache/2.4.53 [David Zuelke]
- blackfire/2.7.0 [David Zuelke]
- Composer/2.2.9 [David Zuelke]

## [v212] - 2022-02-25

### CHG

- Composer/2.2.7 [David Zuelke]

## [v211] - 2022-02-22

### ADD

- PHP/7.4.28 [David Zuelke]
- PHP/8.0.16 [David Zuelke]
- PHP/8.1.3 [David Zuelke]
- ext-blackfire/1.74.1 [David Zuelke]
- ext-redis/5.3.7 [David Zuelke]

### CHG

- blackfire/2.6.0 [David Zuelke]
- Composer/2.2.6 [David Zuelke]

## [v210] - 2022-02-11

### CHG

- For any PHP extension declared as `provide`d by a userland package ("polyfill"), attempt explicit installation after main platform install succeeded [David Zuelke]

## [v209] - 2022-02-10

(no changes; release bump for rolling out v208 repository update)

## [v208] - 2022-02-10

### CHG

- Treat shared PHP extensions the same as third-party extensions during installation e.g. if userland polyfills declare a `provide` for them [David Zuelke]

## [v207] - 2022-02-07

### CHG

- Allow control of Composer repository priority for entries in `$HEROKU_PHP_PLATFORM_REPOSITORIES` [David Zuelke]

## [v206] - 2022-02-01

### ADD

- PHP/8.0.15 [David Zuelke]
- PHP/8.1.2 [David Zuelke]
- ext-blackfire/1.73.0 [David Zuelke]
- ext-imagick/3.7.0 [David Zuelke]
- ext-pcov/1.0.11 [David Zuelke]
- ext-phalcon/4.1.3 [David Zuelke]
- ext-rdkafka/6.0.0 [David Zuelke]
- ext-redis/5.3.6 [David Zuelke]
- Apache/2.4.52 [David Zuelke]

### CHG

- Use Composer 2 for platform installation step [David Zuelke]
- Composer/1.10.25 [David Zuelke]
- Composer/2.2.5 [David Zuelke]

### FIX

- Userland packages declaring PHP extensions as provided cause platform installation failure [David Zuelke]

## [v205] - 2022-01-07

### FIX

- `symfony/polyfill-…` packages' `ext-…` `provide` declarations (added in v1.24) cause install failure (#528) [David Zuelke]

## [v204] - 2022-01-03

### CHG

- Composer/2.2.3 [David Zuelke]
- Forward compatibility for Composer version selection [David Zuelke]

## [v203] - 2021-12-17

## ADD

- PHP/7.4.27 [David Zuelke]
- PHP/8.0.14 [David Zuelke]
- PHP/8.1.1 [David Zuelke]
- ext-blackfire/1.72.0 [David Zuelke]
- ext-mongodb/1.12.0 [David Zuelke]
- ext-psr/1.1.0 (for PHP 7.2) [David Zuelke]
- ext-psr/1.2.0 (for PHP 7.3+) [David Zuelke]

## [v202] - 2012-12-10

### ADD

- ext-amqp/1.11.0 [David Zuelke]
- ext-blackfire/1.71.0 [David Zuelke]
- ext-imagick/3.6.0 [David Zuelke]
- ext-mongodb/1.11.1 [David Zuelke]
- ext-pcov/1.0.10 [David Zuelke]
- ext-rdkafka/5.0.2 [David Zuelke]
- Nginx/1.20.2 [David Zuelke]
- PHP/8.1.0 [David Zuelke]

### CHG

- blackfire/2.5.2 [David Zuelke]
- Composer/2.1.14 [David Zuelke]
- Composer/1.10.24 [David Zuelke]

## [v201] - 2021-11-18

### ADD

- PHP/7.3.33 [Ed Morley]
- PHP/7.4.26 [Ed Morley]
- PHP/8.0.13 [Ed Morley]

## [v200] - 2021-10-28

### ADD

- PHP/7.3.32 [David Zuelke]
- PHP/7.4.25 [David Zuelke]
- PHP/8.0.12 [David Zuelke]
- ext-apcu/5.1.21 [David Zuelke]
- ext-blackfire/1.69.0 [David Zuelke]

### CHG

- blackfire/2.5.1 [David Zuelke]
- librdkafka/1.8.2 [David Zuelke]

### FIX

- Malformed `$COMPOSER_AUTH` causes app startup failure (#513) [David Zuelke]

## [v199] - 2021-10-08

### ADD

- Apache/2.4.51 [David Zuelke]

### CHG

- Composer/2.1.9 [David Zuelke]
- Composer/1.10.23 [David Zuelke]

## [v198] - 2021-09-28

### ADD

- PHP/7.3.31 [David Zuelke]
- PHP/7.4.24 [David Zuelke]
- PHP/8.0.11 [David Zuelke]
- ext-blackfire/1.67.0 [David Zuelke]
- ext-ev/1.1.5 [David Zuelke]
- ext-event/3.0.6 [David Zuelke]
- ext-pq/2.2.0 [David Zuelke]
- Apache/2.4.49 [David Zuelke]
- blackfire/2.5.0 [David Zuelke]

### CHG

- Composer/2.1.8 [David Zuelke]
- librdkafka/1.8.0 [David Zuelke]

## [v197] - 2021-08-26

### ADD

- ext-blackfire/1.65.0 [David Zuelke]
- ext-mongodb/1.10.0 [David Zuelke]
- PHP/7.3.30 [David Zuelke]
- PHP/7.4.23 [David Zuelke]
- PHP/8.0.10 [David Zuelke]
- ext-newrelic/9.18.1.303 [David Zuelke]

### CHG

- Composer/2.1.6 [David Zuelke]

## [v196] - 2021-07-30

### ADD

- blackfire/2.4.3 [David Zuelke]
- PHP/7.4.22 [David Zuelke]
- PHP/8.0.9 [David Zuelke]
- ext-ev/1.1.4 [David Zuelke]
- ext-imagick/3.5.1 [David Zuelke]
- ext-blackfire/1.64.0 [David Zuelke]

### CHG

- Composer/2.1.5 [David Zuelke]

## [v195] - 2021-07-01

### ADD

- PHP/7.3.29 [David Zuelke]
- PHP/7.4.21 [David Zuelke]
- PHP/8.0.8 [David Zuelke]
- ext-blackfire/1.63.0 [David Zuelke]
- Apache/2.4.48 [David Zuelke]

### CHG

- `$HEROKU_PHP_GRACEFUL_SIGTERM` now defaults to "1" on Heroku dynos to enable graceful shutdowns for PHP-FPM, Apache and Nginx [David Zuelke]
- Composer/2.1.3 [David Zuelke]

## [v194] - 2021-06-25

### ADD

- blackfire/2.4.2 [David Zuelke]
- ext-blackfire/1.62.0 [David Zuelke]
- ext-imagick/3.5.0 [David Zuelke]

### CHG

- ext-blackfire installs blackfire agent as separate dependency [David Zuelke]
- ext-blackfire will use blackfire agent from https://github.com/blackfireio/integration-heroku if present [David Zuelke]

### FIX

- ext-blackfire attempts to instrument during web dyno startup [David Zuelke]

## [v193] - 2021-06-07

### ADD

- ext-newrelic for PHP 8 [David Zuelke]
- Nginx/1.20.1 [David Zuelke]
- PHP/7.4.20 [David Zuelke]
- PHP/8.0.7 [David Zuelke]
- ext-pcov/1.0.9 [David Zuelke]
- ext-mongodb/1.9.1 [David Zuelke]
- ext-event/3.0.4 [David Zuelke]
- ext-ev/1.1.2 [David Zuelke]
- ext-apcu/5.1.20 [David Zuelke]

### CHG

- Remove support for heroku-16 [David Zuelke]
- Bump minimum supported PHP version to 7.1.x [David Zuelke]
- librdkafka/1.7.0 [David Zuelke]
- Composer/2.1.2 [David Zuelke]

## [v192] - 2021-05-06

### ADD

- PHP/7.3.28 [David Zuelke]
- ext-phalcon/4.1.2 [David Zuelke]
- ext-newrelic/9.17.1.301 [David Zuelke]
- PHP/7.4.19 [David Zuelke]
- PHP/8.0.6 [David Zuelke]

### CHG

- Composer/1.10.22 [David Zuelke]
- Composer/2.0.13 [David Zuelke]
- Bump ext-apcu_bc (bundled with ext-apcu) to 1.0.5 [David Zuelke]

### FIX

- ext-apcu_bc should only be built for PHP 5/7 [David Zuelke]

## [v191] - 2021-04-15

### ADD

- ext-pcov/1.0.8 [David Zuelke]
- ext-blackfire/1.54.0 [David Zuelke]
- ext-amqp/1.11.0beta (PHP 8.0.* only) [David Zuelke]
- ext-redis/5.3.4 [David Zuelke]
- ext-event/3.0.3 [David Zuelke]

### CHG

- libcassandra/2.16.0 [David Zuelke]
- Composer/1.10.21 [David Zuelke]
- Composer/2.0.12 [David Zuelke]

## [v190] - 2021-03-04

### ADD

- PHP/7.4.16 [David Zuelke]
- PHP/8.0.3 [David Zuelke]
- ext-blackfire/1.50.0 (PHP 5.6) [David Zuelke]
- ext-blackfire/1.51.0 (PHP 7+) [David Zuelke]

### CHG

- If `HEROKU_PHP_GRACEFUL_SIGTERM=1`, gracefully shut down PHP-FPM, Apache/Nginx, and log redirection in environments where all processes (not just the leader) receive a SIGTERM for termination [David Zuelke]
- Composer/2.0.11 [David Zuelke]
- librdkafka/1.6.1 [David Zuelke]

## [v189] - 2021-02-05

### ADD

- ext-rdkafka/5.0.0 [David Zuelke]
- PHP/7.3.27 [David Zuelke]
- PHP/7.4.15 [David Zuelke]
- PHP/8.0.2 [David Zuelke]
- ext-ev/1.1.1 [David Zuelke]
- ext-redis/5.3.3 [David Zuelke]
- ext-blackfire/1.49.1 [David Zuelke]
- ext-newrelic/9.16.0.295 [David Zuelke]

### CHG

- Drop support for cedar-14 [David Zuelke]
- Drop support for HHVM [David Zuelke]
- Drop support for PHP 5.5 [David Zuelke]
- Use PHP 7.4 for bootstrapping [David Zuelke]
- librdkafka/1.6.0 [David Zuelke]
- Composer/1.10.20 [David Zuelke]
- Composer/2.0.9 [David Zuelke]

## [v188] - 2021-01-08

### ADD

- PHP/7.3.26 [David Zuelke]
- PHP/7.4.14 [David Zuelke]
- PHP/8.0.1 [David Zuelke]
- ext-blackfire/1.48.1 [David Zuelke]
- ext-rdkafka/4.1.2 [David Zuelke]

## [v187] - 2020-12-09

### ADD

- ext-rdkafka/4.1.1 [David Zuelke]
- ext-newrelic/9.15.0.293 [David Zuelke]

### CHG

- librdkafka/1.5.3 [David Zuelke]

### FIX

- ext-redis is missing for PHP 8 (#452) [David Zuelke]

## [v186] - 2020-12-07

### ADD

- PHP/7.3.25 [David Zuelke]
- PHP/7.4.13 [David Zuelke]
- PHP/8.0.0 (for stacks `heroku-18` and `heroku-20`) [David Zuelke]
- ext-ev/1.0.9 [David Zuelke]
- ext-mongodb/1.9.0 [David Zuelke]
- ext-blackfire/1.46.4 [David Zuelke]
- ext-event/3.0.2 [David Zuelke]

### CHG

- Default to PHP 8 if possible for heroku-20 [David Zuelke]
- Composer/1.10.19 [David Zuelke]
- Composer/2.0.8 [David Zuelke]

## [v185] - 2020-11-22

### FIX

- composer bin-dir is not available on $PATH to subsequent buildpacks [David Zuelke]
- composer bin-dir exported as relative location in $PATH at runtime [David Zuelke]

## [v184] - 2020-11-20

### ADD

- Support for Composer 2 (#440) [David Zuelke]
- Composer/2.0.7 [David Zuelke]

### CHG

- Install Composer using platform installer [David Zuelke]
- Do not output download progress during `composer install` [David Zuelke]

### FIX

- ext-newrelic prints info messages during startup regardless of `NEW_RELIC_LOG_LEVEL` [David Zuelke]

## [v183] - 2020-11-13

### ADD

- ext-newrelic/9.14.0.290 [David Zuelke]
- PHP/8.0.0RC4 (heroku-20 stack only) [David Zuelke]
- ext-mongodb/1.9.0RC1 (PHP 8 only) [David Zuelke]
- PHP/7.3.24 [David Zuelke]
- PHP/7.4.12 [David Zuelke]
- ext-apcu/5.1.19 [David Zuelke]
- ext-blackfire/1.44.0 [David Zuelke]
- ext-event/3.0.0 [David Zuelke]
- ext-mongodb/1.8.2 [David Zuelke]
- ext-phalcon/4.1.0 [David Zuelke]
- ext-rdkafka/4.0.4 [David Zuelke]
- ext-redis/5.3.2 [David Zuelke]
- ext-uuid/1.2.0 [David Zuelke]
- ext-psr/1.0.1 [David Zuelke]

### CHG

- Patches to optionally ignore SIGTERM in Apache, Nginx and PHP builds (not yet implemented by the buildpack) [David Zuelke]
- librdkafka/1.5.2 [David Zuelke]
- Composer/1.10.17 [David Zuelke]

### FIX

- Explicit ext-newrelic require outputs info messages during builds [David Zuelke]

## [v182] - 2020-10-12

### ADD

- Support for heroku-20 stack [David Zuelke]

## [v181] - 2020-10-01

### ADD

- PHP/7.2.34 [David Zuelke]
- PHP/7.3.23 [David Zuelke]
- PHP/7.4.11 [David Zuelke]
- ext-oauth/2.0.7 [David Zuelke]
- ext-pq/2.1.8 [David Zuelke]
- ext-newrelic/9.13.0.270 [David Zuelke]

## [v180] - 2020-09-15

### ADD

- PHP/7.3.22 [David Zuelke]
- PHP/7.4.10 [David Zuelke]
- ext-blackfire/1.39.1 [David Zuelke]
- ext-event/2.5.7 [David Zuelke]
- ext-oauth/2.0.6 [David Zuelke]

### CHG

- Composer/1.10.13 [David Zuelke]

## [v179] - 2020-08-13

### ADD

- PHP/7.2.33 [David Zuelke]
- PHP/7.3.21 [David Zuelke]
- PHP/7.4.9 [David Zuelke]
- ext-blackfire/1.36.0 [David Zuelke]
- ext-mongodb/1.8.0 [David Zuelke]
- ext-newrelic/9.12.0.268 [David Zuelke]
- Apache/2.4.46 [David Zuelke]

### CHG

- librdkafka/1.5.0 [David Zuelke]
- Composer/1.10.10 [David Zuelke]
- libcassandra/2.15.3 [David Zuelke]

### FIX

- Detection of `composer test` or common testing frameworks on Heroku CI occasionally fails on PHP 7.4 (#388) [David Zuelke]

## [v178] - 2020-07-09

### ADD

- PHP/7.4.8 [David Zuelke]
- PHP/7.3.20 [David Zuelke]
- PHP/7.2.32 [David Zuelke]
- ext-redis/5.3.1 [David Zuelke]
- ext-mongodb/1.7.5 [David Zuelke]

### CHG

- librdkafka/1.4.4 [David Zuelke]
- Composer/1.10.8 [David Zuelke]

## [v177] - 2020-06-18

### ADD

- PHP/7.3.19 [David Zuelke]
- PHP/7.4.7 [David Zuelke]
- ext-blackfire/1.34.3 [David Zuelke]
- ext-newrelic/9.6.0.267 [David Zuelke]
- ext-pcov/1.0.6 (#415) [David Zuelke]

### CHG

- Composer/1.10.7 [David Zuelke]

## [v176] - 2020-05-26

### FIX

- Fix build failures for apps that also use heroku/python, introduced in 04c5e14 (#412) [David Zuelke]

## [v175] - 2020-05-25

### ADD

- PHP/7.2.31 [David Zuelke]
- PHP/7.3.18 [David Zuelke]
- PHP/7.4.6 [David Zuelke]
- ext-redis/5.2.2 [David Zuelke]
- ext-newrelic/9.10.1.263 [David Zuelke]
- ext-phalcon/4.0.6 [David Zuelke]
- ext-blackfire/1.34.0 [David Zuelke]
- ext-event/2.5.6 [David Zuelke]

### CHG

- Support `python` not being symlinked to `python2` [Ed Morley]
- Composer/1.10.6 [David Zuelke]
- librdkafka/1.4.2 [David Zuelke]
- libcassandra/2.15.2 [David Zuelke]

## [v174] - 2020-04-30

### ADD

- PHP/7.2.30 [David Zuelke]
- PHP/7.3.17 [David Zuelke]
- PHP/7.4.5 [David Zuelke]
- Apache/2.4.43 [David Zuelke]
- ext-blackfire/1.33.0 [David Zuelke]
- ext-amqp/1.10.2 [David Zuelke]
- Nginx/1.18.0 [David Zuelke]
- ext-newrelic/9.10.0.262 [David Zuelke]

### CHG

- Composer/1.10.5 [David Zuelke]
- librdkafka/1.4.0 [David Zuelke]

## [v173] - 2020-03-20

### ADD

- ext-phalcon/4.0.5 [David Zuelke]
- ext-mongodb/1.7.4 [David Zuelke]
- ext-redis/5.2.1 [David Zuelke]
- PHP/7.4.4 [David Zuelke]
- PHP/7.3.16 [David Zuelke]
- PHP/7.2.29 [David Zuelke]

### CHG

- Composer/1.10.1 [David Zuelke]
- libcassandra/2.15.1 [David Zuelke]

## [v172] - 2020-02-28

### ADD

- PHP/7.2.28 [David Zuelke]
- PHP/7.3.15 [David Zuelke]
- PHP/7.4.3 [David Zuelke]
- ext-psr/1.0.0 [David Zuelke]
- ext-phalcon/4.0.4 [David Zuelke]
- ext-newrelic/9.7.0.258 [David Zuelke]
- ext-mongodb/1.7.3 [David Zuelke]
- ext-event/2.5.4 [David Zuelke]
- ext-blackfire/1.31.0 [David Zuelke]

### CHG

- Use system libc-client for IMAP extension [David Zuelke]
- Use system libmcrypt on all stacks [David Zuelke]
- Use system libzip on heroku-16 and heroku-18 stacks [David Zuelke]
- Use system libsqlite on heroku-16 and heroku-18 stacks [David Zuelke]
- Use system libonig on heroku-16 and heroku-18 stacks [David Zuelke]

## [v171] - 2020-02-11

### ADD

- ext-mongodb/1.7.1 [David Zuelke]
- ext-oauth/2.0.5 [David Zuelke]
- ext-pq/2.1.7 [David Zuelke]
- ext-rdkafka/4.0.3 [David Zuelke]
- ext-psr/0.7.0 [David Zuelke]
- ext-phalcon/4.0.3 [David Zuelke]

### CHG

- Composer/1.9.3 [David Zuelke]

## [v170] - 2020-02-10

### ADD

- PHP/7.4.2 [David Zuelke]

### CHG

- `$COMPOSER_MEMORY_LIMIT` defaults to dyno memory if information is available [David Zuelke]
- `$COMPOSER_MIRROR_PATH_REPOS` defaults to 1 [David Zuelke]
- `$COMPOSER_NO_INTERACTION` defaults to 1 [David Zuelke]
- `$COMPOSER_PROCESS_TIMEOUT` defaults to 0 at app runtime [David Zuelke]
- Build PHP-FPM with /proc/…/mem based process tracing [David Zuelke]
- Log slow PHP-FPM requests after 3 seconds by default for PHP 7.4 [David Zuelke]
- Terminate slow PHP-FPM requests after 30 seconds by default for PHP 7.4 [David Zuelke]
- Refactor `$WEB_CONCURRENCY` calculation to use `/sys/fs/cgroup/memory/memory.limit_in_bytes` if available [David Zuelke]
- Use all available instance RAM when calculating `$WEB_CONCURRENCY` for PHP 7.4+ running on Performance-L dynos [David Zuelke]
- Use all available instance RAM as default PHP CLI memory_limit [David Zuelke]

## [v169] - 2020-01-26

### CHG

- Try and tell SIGTERM cases apart in boot scripts for more precise messaging on shutdown [David Zuelke]

### FIX

- Shell may emit confusing "... Terminated ..." messages on shutdown [David Zuelke]
- PHP-FPM startup failures may trigger race condition where dyno boot hangs [David Zuelke]

## [v168] - 2020-01-24

### ADD

- PHP/7.2.27 [David Zuelke]
- PHP/7.3.14 [David Zuelke]
- ext-blackfire/1.30.0 [David Zuelke]
- ext-newrelic/9.6.1.256 [David Zuelke]
- ext-pq/2.1.6 [David Zuelke]

### CHG

- Composer/1.9.2 [David Zuelke]
- libcassandra/2.15.0 [David Zuelke]

## [v167] - 2020-01-23

### CHG

- Graceful shutdown for boot scripts on SIGTERM and SIGINT [David Zuelke]
- Dynamically poll for `newrelic-daemon` readiness on dyno boot instead of using blanket two-second wait [David Zuelke]
- Dynamically poll for PHP-FPM readiness on dyno boot instead of using blanket two-second wait [David Zuelke]

## [v166] - 2019-12-20

### ADD

- PHP/7.2.26 [David Zuelke]
- PHP/7.3.13 [David Zuelke]
- ext-rdkafka/4.0.2 [David Zuelke]

## [v165] - 2019-12-11

### ADD

- ext-apcu/5.1.18 [David Zuelke]
- ext-raphf/2.0.1 [David Zuelke]
- ext-phalcon/3.4.5 [David Zuelke]
- ext-redis/5.1.1 [David Zuelke]
- PHP/7.2.25 [David Zuelke]
- PHP/7.3.12 [David Zuelke]
- ext-memcached/3.1.5 [David Zuelke]
- ext-mongodb/1.6.1 [David Zuelke]
- ext-newrelic/9.4.0.249 [David Zuelke]
- ext-ev/1.0.7 [David Zuelke]
- ext-rdkafka/3.1.3 [David Zuelke]
- ext-rdkafka/4.0.0 [David Zuelke]
- ext-blackfire/1.29.4 [David Zuelke]
- ext-uuid/1.1.0 (#371) [David Zuelke]

### CHG

- Composer/1.9.1 [David Zuelke]
- librdkafka/1.3.0 [David Zuelke]
- libcassandra/2.14.1 [David Zuelke]

### FIX

- Revert ext-newrelic/9.2.0.247 due to startup failure [David Zuelke]
- PHP 7.0 builds picking up generic rather than version-specific `heroku.ini` settings [David Zuelke]

## [v164] - 2019-10-24

### ADD

- PHP/7.3.11 [David Zuelke]
- PHP/7.2.24 [David Zuelke]
- PHP/7.1.33 [David Zuelke]
- ext-newrelic/9.2.0.247 [David Zuelke]
- ext-memcached/3.1.4 [David Zuelke]
- ext-rdkafka/4.0.0 [David Zuelke]

### CHG

- Bump `heroku-16.Dockerfile` and `heroku-18.Dockerfile` to tag v18 [David Zuelke]
- librdkafka/1.2.1 [David Zuelke]

## [v163] - 2019-10-01

### CHG

- Pin `heroku-18.Dockerfile` to use `heroku/heroku:18-build.v16` to ensure builds against libssl 1.1.0 until Private Spaces are fully upgraded [David Zuelke]

## [v162] - 2019-09-27

### ADD

- PHP/7.2.23 [David Zuelke]
- PHP/7.3.10 [David Zuelke]
- ext-newrelic/9.1.0.246 [David Zuelke]
- ext-mongodb/1.6.0 (PHP 5.6+ only) [David Zuelke]
- ext-blackfire/1.27.1 [David Zuelke]
- Nginx/1.16.1 [David Zuelke]

### CHG

- librdkafka/1.2.0 [David Zuelke]

## [v161] - 2019-08-30

### ADD

- PHP/7.1.32 [David Zuelke]
- PHP/7.2.22 [David Zuelke]
- PHP/7.3.9 [David Zuelke]

### CHG

- Build PHP with libwebp for ext-gd on heroku-18 (#358) [David Zuelke]

## [v160] - 2019-08-23

### ADD

- ext-newrelic/9.0.2.245 [David Zuelke]
- ext-blackfire/1.27.0 [David Zuelke]
- Apache/2.4.41 [David Zuelke]

### CHG

- Simplify ext-newrelic startup handling [David Zuelke]
- Simplify ext-blackfire startup handling [David Zuelke]
- ext-blackfire now supports `BLACKFIRE_LOG_LEVEL` (4: debug, 3: info, 2: warning, 1: error) [David Zuelke]

### FIX

- Fix HHVM boot scripts failing if a `composer` shell function is present [David Zuelke]

## [v159] - 2019-08-06

### ADD

- Automatically run 'composer test' if present, or one of 'codecept'/'behat'/'phpspec'/'atoum'/'kahlan'/'peridot'/'phpunit', on Heroku CI [David Zuelke]
- PHP/7.1.31 [David Zuelke]
- PHP/7.2.21 [David Zuelke]
- PHP/7.3.8 [David Zuelke]
- ext-rdkafka/3.1.2 [David Zuelke]
- ext-redis/5.0.2 [David Zuelke]
- ext-blackfire/1.26.4 [David Zuelke]

### CHG

- Enable zend.assertions on Heroku CI [David Zuelke]
- Boot scripts now prefer a `composer` binary on `$PATH` over a `composer.phar` in the CWD [David Zuelke]
- Refactor logic used to prevent APM extensions such as `ext-newrelic` or `ext-blackfire` from starting up during during boot preparations or builds [David Zuelke]
- Patch `libc-client`, used by PHP's `ext-imap`, to use SNI if possible (required with TLSv1.3) [David Zuelke]
- Composer/1.9.0 [David Zuelke]

### FIX

- Boot scripts no longer use `php -n` to prevent APM extensions from booting, but instead add an INI file that contains disabling directives for common extensions (#345, #348, #349) [David Zuelke]

## [v158] - 2019-07-04

### ADD

- PHP/7.2.20 [David Zuelke]
- PHP/7.3.7 [David Zuelke]
- ext-blackfire/1.26.2 [David Zuelke]
- ext-event/2.5.3 [David Zuelke]
- ext-phalcon/3.4.4 [David Zuelke]
- ext-rdkafka/3.1.1 [David Zuelke]
- ext-redis/5.0.0 [David Zuelke]

### CHG

- libcassandra/2.13.0 [David Zuelke]
- librdkafka/1.1.0 [David Zuelke]

## [v157] - 2019-06-13

### ADD

- ext-event/2.5.2 [David Zuelke]
- ext-mongodb/1.5.5 [David Zuelke]
- ext-newrelic/8.7.0.242 [David Zuelke]
- ext-blackfire/1.25.0 [David Zuelke]

### CHG

- Composer/1.8.6 [David Zuelke]

### FIX

- Bug in Apache 2.4.39 (https://bz.apache.org/bugzilla/show_bug.cgi?id=63325) causes 408 timeout after 20 seconds on long file uploads (#342) [David Zuelke]
- Phalcon 3.4.3 segfaults on latest PHP 7.3.6 [David Zuelke]

## [v156] - 2019-05-30

### ADD

- PHP/7.1.30 [David Zuelke]
- PHP/7.2.19 [David Zuelke]
- PHP/7.3.6 [David Zuelke]
- ext-ev/1.0.6 [David Zuelke]
- ext-event/2.5.1 [David Zuelke]

### CHG

- librdkafka/1.0.1 [David Zuelke]
- Use bundled `php.ini-production` as the standard PHP config and apply Heroku settings via `conf.d/` include [David Zuelke]
- Update `error_reporting` to `E_ALL & ~E_STRICT` for all runtime versions [David Zuelke]

### FIX

- `mail.add_x_header` INI directive is set to an outdated default value for some PHP versions [David Zuelke]
- `serialize_precision` INI directive is set to an outdated default value for some PHP versions [David Zuelke]
- `session.entropy_length` INI directive is set to an outdated default value for some PHP versions [David Zuelke]
- `session.sid_bits_per_character` INI directive is set to a non-recommended default value for some PHP versions [David Zuelke]
- `url_rewriter.tags` INI directive is set to an outdated default value for some PHP versions [David Zuelke]
- PHP assertions should be disabled in prod mode (#242) [David Zuelke]

## [v155] - 2019-05-09

### ADD

- ext-rdkafka/3.1.0 [David Zuelke]
- ext-event/2.5.0 [David Zuelke]
- ext-imagick/3.4.4 [David Zuelke]
- PHP/7.1.29 [David Zuelke]
- PHP/7.2.18 [David Zuelke]
- PHP/7.3.5 [David Zuelke]

### CHG

- Composer/1.8.5 [David Zuelke]
- libcassandra/2.12.0 [David Zuelke]

## [v154] - 2019-04-04

### ADD

- PHP/7.2.17 [David Zuelke]
- PHP/7.3.4 [David Zuelke]
- Apache/2.4.39 [David Zuelke]
- PHP/7.1.28 [David Zuelke]

### CHG

- librdkafka/1.0.0 [David Zuelke]
- libcassandra/2.11.0 [David Zuelke]

## [v153] - 2019-03-18

### ADD

- ext-newrelic/8.6.0.238 [David Zuelke]
- ext-redis/4.3.0 [David Zuelke]

## [v152] - 2019-03-13

### ADD

- Nginx/1.14.2 (#241, #285) [David Zuelke]
- Update Nginx MIME types for woff and woff2 formats (#286) [David Zuelke]

### CHG

- Restructure Nginx configs and add compatibility with Nginx/1.9.3+ (#198) [David Zuelke]
- Build Nginx with `ngx_http_ssl_module` (#182) [David Zuelke]

## [v151] - 2019-03-08

### ADD

- PHP/7.1.27 [David Zuelke]
- PHP/7.2.16 [David Zuelke]
- PHP/7.3.3 [David Zuelke]
- ext-phalcon/3.4.3 [David Zuelke]
- ext-apcu/5.1.17 [David Zuelke]

### CHG

- Composer/1.8.4 [David Zuelke]

## [v150] - 2019-02-07

### ADD

- ext-blackfire/1.24.4 [David Zuelke]
- Apache/2.4.38 [David Zuelke]
- PHP/7.2.15 [David Zuelke]
- PHP/7.3.2 [David Zuelke]

### CHG

- Composer/1.8.3 [David Zuelke]

### FIX

- ext-oauth doesn't find libcurl headers on heroku-18 (#322) [David Zuelke]

## [v149] - 2019-01-14

### ADD

- ext-memcached/3.1.3 [David Zuelke]
- ext-amqp/1.9.4 [David Zuelke]
- PHP/5.6.40 [David Zuelke]
- PHP/7.1.26 [David Zuelke]
- PHP/7.2.14 [David Zuelke]
- PHP/7.3.1 [David Zuelke]
- ext-pq/2.1.5 [David Zuelke]

### CHG

- Use PHP 7.3 for bootstrapping [David Zuelke]

### FIX

- Boot scripts fail without GNU realpath or GNU readlink (#317) [David Zuelke]

## [v148] - 2018-12-20

### ADD

- ext-apcu/5.1.16 [David Zuelke]
- ext-blackfire/1.24.2 [David Zuelke]
- ext-event/2.4.3 [David Zuelke]
- ext-newrelic/8.5.0.235 [David Zuelke]

### FIX

- BSD grep doesn't support Perl expression mode (#311) [David Zuelke]

## [v147] - 2018-12-13

### ADD

- PHP/7.3.0 [David Zuelke]
- PHP/7.2.13 [David Zuelke]
- PHP/7.1.25 [David Zuelke]
- PHP/7.0.33 [David Zuelke]
- PHP/5.6.39 [David Zuelke]
- ext-phalcon/3.4.2 [David Zuelke]
- ext-newrelic/8.4.0.231 [David Zuelke]
- ext-redis/4.2.0 [David Zuelke]
- ext-apcu/5.1.14 [David Zuelke]
- ext-event/2.4.2 [David Zuelke]

### CHG

- Look for configs relative to buildpack dir, and not to $CWD/vendor/heroku/…, in boot scripts [David Zuelke]
- Look for default configs using version specific paths first in boot scripts [David Zuelke]
- Apply non-default opcache INI settings only to the PHP 5 builds that need them [David Zuelke]
- Composer/1.8.0 [David Zuelke]

## [v146] - 2018-11-08

### ADD

- Apache/2.4.37 [David Zuelke]
- PHP/7.1.24 [David Zuelke]
- PHP/7.2.12 [David Zuelke]

### CHG

- Translate `NEW_RELIC_LOG_LEVEL` values "verbose" and "verbosedebug" to "debug" for `newrelic-daemon` [David Zuelke]
- librdkafka/0.11.6 [David Zuelke]

## [v145] - 2019-10-16

### ADD

- PHP/7.1.23 [David Zuelke]
- PHP/7.2.11 [David Zuelke]
- ext-oauth/2.0.3 [David Zuelke]
- ext-mongodb/1.5.3 [David Zuelke]
- ext-blackfire/1.23.1 [David Zuelke]
- ext-newrelic/8.3.0.226 [David Zuelke]

### FIX

- Nginx reports "localhost" instead of requested hostname in SERVER_NAME FastCGI variable (#264) [David Zuelke]

## [v144] - 2019-09-13

### ADD

- PHP/5.6.38 [David Zuelke]
- PHP/7.0.32 [David Zuelke]
- PHP/7.1.22 [David Zuelke]
- PHP/7.2.10 [David Zuelke]
- ext-newrelic/8.2.0.221 [David Zuelke]
- ext-phalcon/3.4.1 [David Zuelke]

### CHG

- Extra reminders about runtimes and stacks if runtime platform install fails [David Zuelke]
- Warn users of PHP versions that are close to, or have reached, end of life or end of active support [David Zuelke]
- Default to listen.mode=0666 for PHP-FPM socket to allow running in both Heroku Dynos and containers [David Zuelke]

## [v143] - 2018-08-17

### ADD

- PHP/7.2.9 [David Zuelke]
- PHP/7.1.21 [David Zuelke]
- ext-event/2.4.1 [David Zuelke]

### CHG

- Composer/1.7.2 [David Zuelke]

## [v142] - 2018-08-08

### FIX

- Check for 'minimum-stability' may fail if no 'composer.lock' present [David Zuelke]

## [v141] - 2018-08-07

### ADD

- ext-redis/4.1.1 [David Zuelke]
- ext-mongodb/1.5.2 [David Zuelke]

### CHG

- Verbose error messasge on `bin/detect` failure [David Zuelke]
- Emit brief warnings for common regexed build failure cases [David Zuelke]
- Run most internal 'composer' invocations using '--no-plugins' [David Zuelke]
- Composer/1.7.1 [David Zuelke]
- Warn about 'minimum-stability' only if 'prefer-stable' is off [David Zuelke]

### FIX

- Generate Composer package repositories with empty JSON objects, not arrays, where required by Composer 1.7+ [David Zuelke]

## [v140] - 2018-07-25

### CHG

- Improved build error messages [David Zuelke]
- Colors for build errors, warnings and notices [David Zuelke]
- Remove use of composer.phar in project root [David Zuelke]
- Trap unhandled build errors with dedicated message [David Zuelke]
- Summarize all emitted warnings if subsequent build error occurs [David Zuelke]

### FIX

- stdlib download during build init may theoretically fail on download restart [David Zuelke]

## [v139] - 2018-07-20

### ADD

- PHP/5.6.37 [David Zuelke]
- PHP/7.0.31 [David Zuelke]
- PHP/7.1.20 [David Zuelke]
- PHP/7.2.8 [David Zuelke]
- Apache/2.4.34 [David Zuelke]
- ext-redis/4.1.0 [David Zuelke]

### CHG

- librdkafka/0.11.5 [David Zuelke]

## [v138] - 2018-07-10

### ADD

- ext-blackfire/1.22.0 [David Zuelke]
- Argon2 support for PHP 7.2 and heroku-18 [David Zuelke]
- ext-apcu/5.1.12 [David Zuelke]
- ext-mongodb/1.5.1 [David Zuelke]

### FIX

- PHP 7 built with --enable-opcache-file only on cedar-14 [David Zuelke]

## [v137] - 2018-06-26

### ADD

- PHP/7.1.19 [David Zuelke]
- PHP/7.2.7 [David Zuelke]
- ext-blackfire/1.20.1 [David Zuelke]
- ext-phalcon/3.4.0 [David Zuelke]
- ext-pq/2.1.4 [David Zuelke]
- ext-mongodb/1.5.0 [David Zuelke]

### FIX

- New Relic daemon location is broken in PHP INI [David Zuelke]

## [v136] - 2018-05-24

### ADD

- ext-blackfire/1.20.0 [David Zuelke]
- ext-newrelic/8.1.0.209 [David Zuelke]
- PHP/7.1.18 [David Zuelke]
- PHP/7.2.6 [David Zuelke]

### CHG

- Default to PHP 7 for heroku-18 and later [David Zuelke]
- Composer/1.6.5 [David Zuelke]

## [v135] - 2018-04-26

### ADD

- PHP/5.6.36 [David Zuelke]
- PHP/7.0.30 [David Zuelke]
- PHP/7.1.17 [David Zuelke]
- PHP/7.2.5 [David Zuelke]
- ext-mongodb/1.4.3 [David Zuelke]
- ext-redis/4.0.2 [David Zuelke]

### CHG

- Composer/1.6.4 [David Zuelke]
- libcassandra/2.9.0 [David Zuelke]

## [v134] - 2018-03-30

### ADD

- Apache/2.4.33 [David Zuelke]
- ext-newrelic/8.0.0.204 [David Zuelke]
- ext-apcu/5.1.11 [David Zuelke]
- ext-mongodb/1.4.2 [David Zuelke]
- PHP/7.0.29 [David Zuelke]
- PHP/7.1.16 [David Zuelke]
- PHP/7.2.4 [David Zuelke]
- ext-phalcon/3.3.2 [David Zuelke]
- PHP/5.6.35 [David Zuelke]

### CHG

- librdkafka/0.11.4 [David Zuelke]

## [v133] - 2018-03-21

### CHG

- Internal changes only [David Zuelke]

## [v132] - 2018-03-02

### ADD

- PHP/5.6.34 [David Zuelke]
- PHP/7.0.28 [David Zuelke]
- PHP/7.1.15 [David Zuelke]
- PHP/7.2.3 [David Zuelke]
- ext-mongodb/1.4.1 [David Zuelke]
- ext-apcu/5.1.10 [David Zuelke]
- ext-apcu_bc/1.0.4 [David Zuelke]

### CHG

- libcassandra/2.8.1 [David Zuelke]

## [v131] - 2018-02-12

### ADD

- PHP/7.1.14 [David Zuelke]
- PHP/7.2.2 [David Zuelke]
- ext-blackfire/1.18.2 [David Zuelke]
- ext-mongodb/1.4.0 [David Zuelke]

### CHG

- Enable ext-sodium for PHP 7.2 on stack heroku-16 [David Zuelke]
- Composer/1.6.3 [David Zuelke]
- Use Linux abstract socket for New Relic daemon communications [David Zuelke]

## [v130] - 2018-01-11

### ADD

- ext-newrelic/7.7.0.203 [David Zuelke]

## [v129] - 2018-01-10

### ADD

- ext-phalcon/3.3.1 [David Zuelke]
- ext-pq/2.1.3 [David Zuelke]

### CHG

- Composer/1.6.2 [David Zuelke]

## [v128] - 2018-01-04

### ADD

- PHP/5.6.33 [David Zuelke]
- PHP/7.0.27 [David Zuelke]
- PHP/7.1.13 [David Zuelke]
- PHP/7.2.1 [David Zuelke]
- ext-blackfire/1.18.0 for PHP 7.2 [David Zuelke]
- ext-apcu/5.1.9 [David Zuelke]
- ext-mongodb/1.3.4 [David Zuelke]
- ext-phalcon/3.3.0 [David Zuelke]
- ext-redis/3.1.6 [David Zuelke]

### CHG

- Composer/1.6.0 [David Zuelke]
- librdkafka/0.11.3 [David Zuelke]

## [v127] - 2017-11-30

### ADD

- ext-rdkafka/3.0.5 [David Zuelke]
- ext-mongodb/1.3.3 [David Zuelke]
- ext-memcached/3.0.4 [David Zuelke]
- PHP/7.0.26 [David Zuelke]
- PHP/7.1.12 [David Zuelke]
- PHP/7.2.0 [David Zuelke]

### CHG

- libcassandra/2.8.0 [David Zuelke]

### FIX

- Heroku\Buildpack\PHP\Downloader::download() is missing optional third argument [David Zuelke]
- Files like `composer.js` or similar are inaccessible in web root (#247) [David Zuelke]

## [v126] - 2017-10-29

### ADD

- PHP/5.6.32 [David Zuelke]
- PHP/7.0.25 [David Zuelke]
- PHP/7.1.11 [David Zuelke]
- ext-newrelic/7.6.0.201 [David Zuelke]
- ext-mongodb/1.3.1 [David Zuelke]
- ext-amqp/1.9.3 [David Zuelke]
- ext-phalcon/3.2.4 [David Zuelke]
- Apache/2.4.29 [David Zuelke]

### CHG

- Ignore `require-dev` when building platform package dependency graph (#240) [David Zuelke]
- Rewrite `provide` sections with PHP extensions in package definitions to `replace` for known polyfill packages [David Zuelke]
- libcassandra/2.7.1 [David Zuelke]
- librdkafka/0.11.1 [David Zuelke]

### FIX

- gmp.h lookup patching broken since v125 / d024b14 [David Zuelke]

## [v125] - 2017-10-04

### ADD

- PHP/7.0.24 [David Zuelke]
- PHP/7.1.10 [David Zuelke]
- ext-redis/3.1.4 [David Zuelke]
- ext-mongodb/1.3.0 [David Zuelke]
- ext-blackfire/1.18.0 [David Zuelke]

### CHG

- Composer/1.5.2 [David Zuelke]

## [v124] - 2017-09-07

### FIX

- Use Composer/1.5.1 [David Zuelke]

## [v123] - 2017-09-07

### ADD

- ext-mongo/1.6.16 [David Zuelke]
- ext-newrelic/7.5.0.199 [David Zuelke]
- ext-cassandra/1.3.2 [David Zuelke]
- ext-rdkafka/3.0.4 [David Zuelke]
- ext-phalcon/3.2.2 [David Zuelke]
- PHP/7.1.9 [David Zuelke]
- PHP/7.0.23 [David Zuelke]
- ext-mongodb/1.2.10 [David Zuelke]

### CHG

- Support "heroku-sys-library" package type in platform installer [David Zuelke]
- Add new argument for "provide" platform package manifest entry to `manifest.py` [David Zuelke]
- Move libcassandra to its own package, installed as a dependency by platform installer [David Zuelke]
- Move libmemcached to its own package, installed as a dependency by platform installer (if the platform doesn't already provide it) [David Zuelke]
- Move librdkafka to its own package, installed as a dependency by platform installer [David Zuelke]
- libcassandra/2.7.0 [David Zuelke]
- librdkafka/0.11.0 [David Zuelke]
- Composer/1.5.1 [David Zuelke]

## [v122] - 2017-08-03

### ADD

- ext-mongodb/1.2.9 [David Zuelke]
- ext-amqp/1.9.1 [David Zuelke]
- ext-blackfire/1.17.3 [David Zuelke]
- ext-newrelic/7.4.0.198 [David Zuelke]
- ext-phalcon/3.2.1 [David Zuelke]
- ext-pq/2.1.2 [David Zuelke]
- ext-redis/3.1.3 [David Zuelke]
- ext-rdkafka/3.0.3 [David Zuelke]
- PHP/7.0.22 [David Zuelke]
- PHP/7.1.8 [David Zuelke]
- PHP/5.6.31 [David Zuelke]

### CHG

- Do not auto-enable ext-newrelic and ext-blackfire in Heroku CI runs [David Zuelke]
- Composer/1.4.2 [David Zuelke]
- Do not error if buildpack package is installed during Heroku CI runs [David Zuelke]

## [v121] - 2017-03-28

### ADD

- ext-blackfire/1.15.0 [David Zuelke]
- PHP/7.0.17 [David Zuelke]
- PHP/7.1.3 [David Zuelke]
- ext-cassandra/1.3.0 [David Zuelke]
- ext-mongodb/1.2.8 [David Zuelke]
- ext-amqp/1.9.0 (for heroku-16 only) [David Zuelke]
- ext-newrelic/7.1.0.187 [David Zuelke]
- ext-redis/3.1.2 [David Zuelke]
- ext-event/2.3.0 [David Zuelke]
- ext-phalcon/3.1.1 [David Zuelke]

### CHG

- Default to `web: heroku-php-apache2` process in case of empty `Procfile` [David Zuelke]
- libcassandra-2.6.0 [David Zuelke]
- librdkafka/0.9.4 [David Zuelke]
- Composer/1.4.1 [David Zuelke]
- Default to `web: heroku-php-apache2` (without explicit composer bin dir) process in case of missing `Procfile` [David Zuelke]

### FIX

- Failed download during bootstrap fails without meaningful error message [David Zuelke]

## [v120] - 2017-02-20

### ADD

- ext-blackfire/1.14.3 [David Zuelke]
- ext-mongodb/1.2.5 [David Zuelke]
- ext-redis/3.1.1 [David Zuelke]
- ext-imagick/3.4.3 [David Zuelke]
- ext-rdkafka/3.0.1 [David Zuelke]
- PHP/7.0.16 [David Zuelke]
- PHP/7.1.2 [David Zuelke]
- ext-memcached/3.0.3 [David Zuelke]

### CHG

- Allow overwriting of Apache access log format (now named `heroku`) in config include [David Zuelke]
- Composer/1.3.2 [David Zuelke]
- Use system libmcrypt and libmemcached on heroku-16 [David Zuelke]
- librdkafka/0.9.3 [David Zuelke]
- Enable `mod_proxy_wstunnel` in Apache config [David Zuelke]

## [v119] - 2017-01-21

### FIX

- Revert: ext-redis/3.1.0 [David Zuelke]
- Revert: Composer/1.3.1 [David Zuelke]

## [v118] - 2017-01-20

### ADD

- ext-redis/3.1.0 [David Zuelke]
- ext-rdkafka/3.0.0 [David Zuelke]
- ext-phalcon/3.0.3 [David Zuelke]
- ext-blackfire/1.14.2 [David Zuelke]
- ext-apcu/5.1.8 [David Zuelke]
- ext-mongodb/1.2.3 [David Zuelke]
- PHP/5.6.30 [David Zuelke]
- PHP/7.0.15 [David Zuelke]
- PHP/7.1.1 [David Zuelke]
- ext-newrelic/6.9.0 [David Zuelke]

### CHG

- Composer/1.3.1 [David Zuelke]
- Ignore `WEB_CONCURRENCY` values with leading zeroes [David Zuelke]
- Default `NEW_RELIC_APP_NAME` to `HEROKU_APP_NAME` [Christophe Coevoet]

## [v117] - 2016-12-09

### ADD

- ext-ev/1.0.4 [David Zuelke]
- ext-mongodb/1.2.1 [David Zuelke]
- PHP/7.0.14 [David Zuelke]
- PHP/5.6.29 [David Zuelke]

### CHG

- Composer/1.2.4 [David Zuelke]

## [v116] - 2016-12-01

### ADD

- PHP/7.1.0 [David Zuelke]
- ext-phalcon/3.0.2 [David Zuelke]
- ext-rdkafka/2.0.1 [David Zuelke]
- ext-mongodb/1.2.0 [David Zuelke]

### FIX

- Implicit and explicit stability flags for platform packages got ignored [David Zuelke]

## [v115] - 2016-11-23

### ADD

- ext-blackfire/1.14.1 [David Zuelke]

### CHG

- composer.json "require" or dependencies must now contain a runtime version requirement if "require-dev" or dependencies contain one [David Zuelke]

## [v114] - 2016-11-10

### ADD

- ext-apcu/5.1.7 [David Zuelke]
- ext-mongodb/1.1.9 [David Zuelke]
- ext-newrelic/6.8.0.177 [David Zuelke]
- PHP/7.0.13 [David Zuelke]
- PHP/5.6.28 [David Zuelke]
- ext-event/2.2.1 [David Zuelke]

### CHG

- Composer/1.2.2 [David Zuelke]
- Update to librdkafka-0.9.2 final for ext-rdkafka [David Zuelke]

## [v113] - 2016-10-19

### ADD

- ext-newrelic/6.7.0 [David Zuelke]
- ext-blackfire/1.13.0 [David Zuelke]
- ext-apcu/5.1.6 [David Zuelke]
- PHP/5.6.27 [David Zuelke]
- PHP/7.0.12 [David Zuelke]
- ext-rdkafka/1.0.0 [David Zuelke]
- ext-rdkafka/2.0.0 [David Zuelke]

## [v112] - 2016-09-20

### FIX

- Use Composer/1.2.1 [David Zuelke]

## [v111] - 2016-09-20

### ADD

- ext-newrelic/6.6.1.172 [David Zuelke]
- PHP/5.6.26 [David Zuelke]
- PHP/7.0.11 [David Zuelke]

### CHG

- Use Composer/1.2.1 [David Zuelke]

## [v110] - 2016-08-26

### ADD

- ext-ev/1.0.3 [David Zuelke]
- ext-phalcon/2.0.13 [David Zuelke]
- ext-cassandra/1.2.2 [David Zuelke]
- ext-blackfire/1.12.0 [David Zuelke]
- ext-newrelic/6.6.0 [David Zuelke]
- PHP/5.6.25 [David Zuelke]
- PHP/7.0.10 [David Zuelke]
- ext-phalcon/3.0.1 [David Zuelke]

### CHG

- Retry downloads up to three times during bootstrapping [David Zuelke]
- Composer/1.2.0 [David Zuelke]

## [v109] - 2016-07-21

### ADD

- PHP/7.0.9 [David Zuelke]
- PHP/5.6.24 [David Zuelke]
- PHP/5.5.38 [David Zuelke]

## [v108] - 2016-07-08

### ADD

- ext-oauth/2.0.2 [David Zuelke]
- ext-mongodb/1.1.8 [David Zuelke]
- ext-blackfire/1.11.1 [David Zuelke]
- PHP/5.5.37 [David Zuelke]
- PHP/5.6.23 [David Zuelke]
- PHP/7.0.8 [David Zuelke]

### CHG

- Composer/1.1.3 [David Zuelke]

### FIX

- Revert to ext-redis/2.2.7 due to reported segfaults/memleaks [David Zuelke]

## [v107] - 2016-06-18

### ADD

- ext-redis/2.2.8 [David Zuelke]
- ext-redis/3.0.0 [David Zuelke]
- ext-newrelic/6.4.0 [David Zuelke]
- ext-blackfire/1.10.6 [David Zuelke]

### FIX

- Custom `COMPOSER` env var breaks platform installs [David Zuelke]

## [v106] - 2016-06-08

### ADD

- ext-mongodb/1.1.7 [David Zuelke]
- ext-cassandra/1.1.0 [David Zuelke]
- ext-apcu/5.1.5 [David Zuelke]
- ext-event/2.1.0 [David Zuelke]

### CHG

- Use Composer/1.1.2 [David Zuelke]

## [v105] - 2016-05-27

### ADD

- PHP/5.5.36 [David Zuelke]
- PHP/5.6.22 [David Zuelke]
- PHP/7.0.7 [David Zuelke]

## [v104] - 2016-05-20

### ADD

- ext-pq/1.1.1 and 2.1.1 [David Zuelke]

## [v103] - 2016-05-20

### ADD

- ext-pq/1.0.1 and 2.0.1 [David Zuelke]
- ext-apcu/5.1.4 [David Zuelke]
- ext-newrelic/6.3.0.161 [David Zuelke]
- ext-ev/1.0.0 [David Zuelke]

### CHG

- Composer/1.1.1 [David Zuelke]

## [v102] - 2016-04-29

### ADD

- ext-newrelic/6.2.0 [David Zuelke]
- ext-blackfire/1.10.5 [David Zuelke]
- ext-apcu/4.0.11 [David Zuelke]
- ext-event/2.0.4 [David Zuelke]
- ext-imagick/3.4.2 [David Zuelke]
- ext-mongo/1.6.14 [David Zuelke]
- PHP/5.5.35 [David Zuelke]
- PHP/5.6.21 [David Zuelke]
- PHP/7.0.6 [David Zuelke]

### CHG

- Bundle `blackfire` CLI binary with ext-blackfire [David Zuelke]
- Build PHP with `php-cgi` executable [David Zuelke]
- Composer/1.0.3 [David Zuelke]

## [v101] - 2016-04-12

### ADD

- ext-event/2.0.2 [David Zuelke]
- ext-mongodb/1.1.6 [David Zuelke]
- Apache/2.4.20 [David Zuelke]
- ext-blackfire/1.10.3 [David Zuelke]

### CHG

- Use Composer/1.0.0 stable [David Zuelke]

## [v100] - 2016-03-31

### ADD

- ext-imap for all PHP versions [David Zuelke]
- ext-pq/1.0.0 and 2.0.0 [David Zuelke]
- PHP/7.0.5 [David Zuelke]
- PHP/5.6.20 [David Zuelke]
- PHP/5.5.34 [David Zuelke]

### CHG

- Return to using built-in default value for the `pcre.jit` PHP INI setting [David Zuelke]
- Use Composer/1.0.0beta2 [David Zuelke]
- Use first configured platform repository to load components for bootstrapping [David Zuelke]

## [v99] - 2016-03-23

### FIX

- Automatic extensions (blackfire, newrelic) may fail to get installed with many dependencies [David Zuelke]

## [v98] - 2016-03-21

### ADD

- ext-event/2.0.1 [David Zuelke]
- ext-mongo/1.6.13 [David Zuelke]
- ext-mongodb/1.1.5 [David Zuelke]
- ext-oauth/2.0.1 [David Zuelke]
- ext-newrelic/6.1.0.157 [David Zuelke]
- ext-blackfire/1.10.0 [David Zuelke]

### CHG

- Remove GitHub API rate limit checks during build time [David Zuelke]
- Change pcre.jit to 0 in php.ini [David Zuelke]

## [v97] - 2016-03-10

### CHG

- Temporarily downgrade to ext-newrelic/5.1.1.130 [David Zuelke]

## [v96] - 2016-03-10

### ADD

- ext-imagick/3.4.1 for all PHP versions, with platform imagemagick [David Zuelke]
- ext-mongodb/1.1.3 [David Zuelke]
- ext-ldap, with SASL, for PHP builds (#131) [David Zuelke]
- ext-gmp for PHP builds (#117) [David Zuelke]
- ext-event/2.0.0 [David Zuelke]
- apcu_bc for ext-apcu on PHP 7 (#137) [David Zuelke]
- ext-newrelic/6.0.1.156 (#153) [David Zuelke]

### CHG

- Use Composer/1.0.0beta1 [David Zuelke]
- Remove vendored ICU library and use platform ICU52 for PHP [David Zuelke]
- Remove vendored zlib and use platform version for PHP and Apache [David Zuelke]
- Remove vendored pcre library and use platform version for Apache [David Zuelke]
- Use platform pcre and zlib for Nginx [David Zuelke]
- Update vendored gettext to 0.19.7 and build only its runtime parts [David Zuelke]
- Use platform libsasl for libmemcached [David Zuelke]
- Strip platform packages on build install [David Zuelke]
- Ignore platform package replace/provide/conflict from root `composer.json` on platform package install [David Zuelke]

### FIX

- Platform installer is incompatible with PHP 5.5 [David Zuelke]

## [v95] - 2016-03-03

### ADD

- PHP/5.5.33 [David Zuelke]
- PHP/5.6.19 [David Zuelke]
- PHP/7.0.4 [David Zuelke]
- ext-blackfire/1.9.2 [David Zuelke]
- Nginx/1.8.1 [David Zuelke]
- Apache/2.4.18 [David Zuelke]

## [v94] - 2016-02-26

### FIX

- No web servers get selected when a `composer.lock` is missing [David Zuelke]

## [v93] - 2016-02-26

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

## [v92] - 2016-02-09

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

## [v91] - 2016-01-08

### ADD

- ext-phalcon/2.0.9 [David Zuelke]
- PHP/7.0.2 [David Zuelke]
- PHP/5.6.17 [David Zuelke]
- PHP/5.5.31 [David Zuelke]
- ext-apcu/5.1.2 [David Zuelke]
- ext-mongodb/1.1.2 [David Zuelke]
- ext-oauth/2.0.0 [David Zuelke]

## [v90] - 2015-12-18

### ADD

- PHP/7.0.1 [David Zuelke]

### CHG

- Double default INI setting values for `opcache.memory_consumption`, `opcache.interned_strings_buffer` and `opcache.max_accelerated_files` [David Zuelke]

## [v89] - 2015-12-15

### FIX

- HHVM builds failing when trying to install New Relic or Blackfire [David Zuelke]

## [v88] - 2015-12-15

### CHG

- Big loud warnings if `composer.lock` is outdated (or even broken) [David Zuelke]
- Auto-install `ext-blackfire` and `ext-newrelic` at the very end of the build to avoid them instrumenting build steps or cluttering output with startup messages [David Zuelke]

### FIX

- Buildpack does not export PATH for multi-buildpack usage [David Zuelke]
- Composer limitation leads to lower than possible PHP versions getting resolved [David Zuelke]
- `lib-` platform package requirements may prevent dependency resolution [David Zuelke]
- Invalid/broken `composer.lock` produces confusing error message [David Zuelke]

## [v87] - 2015-12-11

### CHG

- Further improve error information on failed system package install [David Zuelke]
- Notice if implicit version selection based on dependencies' requirements is made [David Zuelke]

### FIX

- "`|`" operators in `composer.lock` platform package requirements break system package dependency resolution [David Zuelke]
- Notice about missing runtime version selector does not show up in all cases [David Zuelke]

## [v86] - 2015-12-10

### ADD

- PHP/7.0.0 [David Zuelke]
- PHP/5.6.16 [David Zuelke]
- ext-apcu/4.0.10 [David Zuelke]
- ext-mongo/1.6.12 [David Zuelke]
- ext-imagick/3.3.0 [David Zuelke]
- ext-blackfire/1.7.0 [David Zuelke]

### CHG

- Rewrite most of the build process; system packages are now installed using a custom Composer installer and Composer repository [David Zuelke]

## [v83] - 2015-11-16

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

## [v82] - 2015-10-31

### CHG

- Downgrade Apache 2.4.17 to Apache 2.4.16 due to `REDIRECT_URL` regression [David Zuelke]

## [v81] - 2015-10-30

### ADD

- PHP/7.0.0RC6 [David Zuelke]
- PHP/5.6.15 [David Zuelke]

## [v80] - 2015-10-15

### ADD

- Nginx/1.8.0 [David Zuelke]
- Apache/2.4.17 [David Zuelke]
- PHP/7.0.0RC5 [David Zuelke]

### CHG

- Use system default php.ini config instead of buildpacks' if no custom config given [David Zuelke]

## [v79] - 2015-10-08

### CHG

- Enable Apache modules `ssl_module` and `mod_proxy_html` (with `mod_xml2enc` dependency) by default [David Zuelke]

## [v78] - 2015-10-01

### ADD

- PHP/7.0.0RC4 [David Zuelke]
- PHP/5.5.30 [David Zuelke]
- PHP/5.6.14 [David Zuelke]

## [v77] - 2015-09-17

### ADD

- PHP/7.0.0RC3 [David Zuelke]

## [v76] - 2015-09-08

### ADD

- ext-mongo/1.6.11 [David Zuelke]
- PHP/7.0.0RC2 [David Zuelke]
- PHP/5.5.29 [David Zuelke]
- PHP/5.6.13 [David Zuelke]

## [v75] - 2015-08-21

### FIX

- Prevent potential (benign) Python notice during builds

## [v74] - 2015-08-21

### FIX

- Warning about missing composer.lock is thrown incorrectly for some composer.json files

## [v72] - 2015-08-21

### ADD

- PHP/5.6.12 [David Zuelke]
- PHP/5.5.28 [David Zuelke]
- ext-newrelic/4.23.4.113 [David Zuelke]
- PHP/7.0.0RC1 [David Zuelke]
- Support custom `composer.json`/`composer.lock` file names via `$COMPOSER` env var [David Zuelke]

### CHG

- A composer.lock is now required if there is any entry in the "require" section of composer.json [David Zuelke]

## [v71] - 2015-07-14

### ADD

- ext-newrelic/4.23.1.107 [David Zuelke]

### FIX

- Apache `mod_proxy_fgci`'s "disablereuse=off" config flag causes intermittent blank pages with HTTPD 2.4.11+ [David Zuelke]
- Applications on cedar-10 can select non-existing PHP 7.0.0beta1 package via composer.json [David Zuelke]

## [v70] - 2015-07-10

### ADD

- PHP/7.0.0beta1 [David Zuelke]
- PHP/5.6.11 [David Zuelke]
- PHP/5.5.27 [David Zuelke]
- ext-newrelic/4.23.0.102 [David Zuelke]
- ext-mongo/1.6.10 [David Zuelke]
- Support auto-tuning for IX dyno type [David Zuelke]

### CHG

- Warn about missing extensions for "blackfire" and "newrelic" add-ons during startup [David Zuelke]

## [v69] - 2015-06-12

### ADD

- PHP/5.5.26 [David Zuelke]
- PHP/5.6.10 [David Zuelke]
- ext-newrelic/4.22.0.99 [David Zuelke]
- ext-mongo/1.6.9 [David Zuelke]

## [v68] - 2015-05-18

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

## [v67] - 2015-03-24

### ADD

- ext-mongo/1.6.6 [David Zuelke]
- PHP/5.6.7 [David Zuelke]
- PHP/5.5.23 [David Zuelke]

### CHG

- Don't run composer install for empty composer.json [David Zuelke]
- Unset GIT_DIR at beginning of compile [David Zuelke]

## [v66] - 2015-03-05

### ADD

- ext-newrelic/4.19.0.90 [David Zuelke]

## [v65] - 2015-03-03

### ADD

- ext-redis/2.2.7 [David Zuelke]
- ext-mongo/1.6.4 [David Zuelke]
- HHVM/3.3.4 [David Zuelke]

### CHG

- Composer uses stderr now for most output, indent that accordingly [David Zuelke]

## [v64] - 2015-02-19

### ADD

- HHVM/3.5.1 [David Zuelke]
- PHP/5.6.6 [David Zuelke]
- PHP/5.5.22 [David Zuelke]
- ext-newrelic/4.18.0.89 [David Zuelke]
- ext-mongo/1.6.3 [David Zuelke]

## [v63] - 2015-02-11

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

## [v62] - 2015-02-04

### FIX

- Broken PHP memlimit check [David Zuelke]

## [v61] - 2015-02-04

### CHG

- Port autotuning to HHVM-Nginx [David Zuelke]

### FIX

- Workaround for Composer's complaining about outdated version warnings on stdout instead of stderr, breaking calls in a few places under certain circumstances [David Zuelke]

## [v60] - 2015-02-04

### ADD

- Auto-tune number of workers based on dyno size and configured memory limit [David Zuelke]

## [v59] - 2015-01-29

### ADD

- ext-mongo/1.6.0 (tag: v59) [David Zuelke]

### CHG

- Improvements to INI handling for HHVM, including new `-I` switch to allow passing additional INI files at boot [David Zuelke]
- Massively improved subprocess and signal handling in boot scripts [David Zuelke]

## [v58] - 2015-01-26

### ADD

- HHVM/3.5.0 [David Zuelke]
- PHP/5.6.5 [David Zuelke]
- PHP/5.5.21 [David Zuelke]

## [v57] - 2015-01-19

### CHG

- Update to Composer dev version for `^` selector support [David Zuelke]

## [v56] - 2015-01-13

### ADD

- ext/oauth 1.2.3 [David Zuelke]
- HHVM/3.3.3 [David Zuelke]
- Run 'composer compile' for custom scripts at the end of deploy [David Zuelke]

## [v55] - 2015-01-07

### FIX

- Standard logs have the wrong $PORT in the file name if the -p option is used in boot scripts [David Zuelke]

## [v54] - 2015-01-05

### ADD

- ext-newrelic/4.17.0.83 [David Zuelke]

### CHG

- Auto-set and follow (but not enable, for now) the FPM slowlog [David Zuelke]

[unreleased]: https://github.com/heroku/heroku-buildpack-php/compare/v254...main
[v254]: https://github.com/heroku/heroku-buildpack-php/compare/v253...v254
[v253]: https://github.com/heroku/heroku-buildpack-php/compare/v252...v253
[v252]: https://github.com/heroku/heroku-buildpack-php/compare/v251...v252
[v251]: https://github.com/heroku/heroku-buildpack-php/compare/v250...v251
[v250]: https://github.com/heroku/heroku-buildpack-php/compare/v249...v250
[v249]: https://github.com/heroku/heroku-buildpack-php/compare/v248...v249
[v248]: https://github.com/heroku/heroku-buildpack-php/compare/v247...v248
[v247]: https://github.com/heroku/heroku-buildpack-php/compare/v246...v247
[v246]: https://github.com/heroku/heroku-buildpack-php/compare/v245...v246
[v245]: https://github.com/heroku/heroku-buildpack-php/compare/v244...v245
[v244]: https://github.com/heroku/heroku-buildpack-php/compare/v243...v244
[v243]: https://github.com/heroku/heroku-buildpack-php/compare/v242...v243
[v242]: https://github.com/heroku/heroku-buildpack-php/compare/v241...v242
[v241]: https://github.com/heroku/heroku-buildpack-php/compare/v240...v241
[v240]: https://github.com/heroku/heroku-buildpack-php/compare/v239...v240
[v239]: https://github.com/heroku/heroku-buildpack-php/compare/v238...v239
[v238]: https://github.com/heroku/heroku-buildpack-php/compare/v237...v238
[v237]: https://github.com/heroku/heroku-buildpack-php/compare/v236...v237
[v236]: https://github.com/heroku/heroku-buildpack-php/compare/v235...v236
[v235]: https://github.com/heroku/heroku-buildpack-php/compare/v234...v235
[v234]: https://github.com/heroku/heroku-buildpack-php/compare/v233...v234
[v233]: https://github.com/heroku/heroku-buildpack-php/compare/v232...v233
[v232]: https://github.com/heroku/heroku-buildpack-php/compare/v231...v232
[v231]: https://github.com/heroku/heroku-buildpack-php/compare/v230...v231
[v230]: https://github.com/heroku/heroku-buildpack-php/compare/v229...v230
[v229]: https://github.com/heroku/heroku-buildpack-php/compare/v228...v229
[v228]: https://github.com/heroku/heroku-buildpack-php/compare/v227...v228
[v227]: https://github.com/heroku/heroku-buildpack-php/compare/v226...v227
[v226]: https://github.com/heroku/heroku-buildpack-php/compare/v225...v226
[v225]: https://github.com/heroku/heroku-buildpack-php/compare/v224...v225
[v224]: https://github.com/heroku/heroku-buildpack-php/compare/v223...v224
[v223]: https://github.com/heroku/heroku-buildpack-php/compare/v222...v223
[v222]: https://github.com/heroku/heroku-buildpack-php/compare/v221...v222
[v221]: https://github.com/heroku/heroku-buildpack-php/compare/v220...v221
[v220]: https://github.com/heroku/heroku-buildpack-php/compare/v219...v220
[v219]: https://github.com/heroku/heroku-buildpack-php/compare/v218...v219
[v218]: https://github.com/heroku/heroku-buildpack-php/compare/v217...v218
[v217]: https://github.com/heroku/heroku-buildpack-php/compare/v216...v217
[v216]: https://github.com/heroku/heroku-buildpack-php/compare/v215...v216
[v215]: https://github.com/heroku/heroku-buildpack-php/compare/v214...v215
[v214]: https://github.com/heroku/heroku-buildpack-php/compare/v213...v214
[v213]: https://github.com/heroku/heroku-buildpack-php/compare/v212...v213
[v212]: https://github.com/heroku/heroku-buildpack-php/compare/v211...v212
[v211]: https://github.com/heroku/heroku-buildpack-php/compare/v210...v211
[v210]: https://github.com/heroku/heroku-buildpack-php/compare/v209...v210
[v209]: https://github.com/heroku/heroku-buildpack-php/compare/v208...v209
[v208]: https://github.com/heroku/heroku-buildpack-php/compare/v207...v208
[v207]: https://github.com/heroku/heroku-buildpack-php/compare/v206...v207
[v206]: https://github.com/heroku/heroku-buildpack-php/compare/v205...v206
[v205]: https://github.com/heroku/heroku-buildpack-php/compare/v204...v205
[v204]: https://github.com/heroku/heroku-buildpack-php/compare/v203...v204
[v203]: https://github.com/heroku/heroku-buildpack-php/compare/v202...v203
[v202]: https://github.com/heroku/heroku-buildpack-php/compare/v201...v202
[v201]: https://github.com/heroku/heroku-buildpack-php/compare/v200...v201
[v200]: https://github.com/heroku/heroku-buildpack-php/compare/v199...v200
[v199]: https://github.com/heroku/heroku-buildpack-php/compare/v198...v199
[v198]: https://github.com/heroku/heroku-buildpack-php/compare/v197...v198
[v197]: https://github.com/heroku/heroku-buildpack-php/compare/v196...v197
[v196]: https://github.com/heroku/heroku-buildpack-php/compare/v195...v196
[v195]: https://github.com/heroku/heroku-buildpack-php/compare/v194...v195
[v194]: https://github.com/heroku/heroku-buildpack-php/compare/v193...v194
[v193]: https://github.com/heroku/heroku-buildpack-php/compare/v192...v193
[v192]: https://github.com/heroku/heroku-buildpack-php/compare/v191...v192
[v191]: https://github.com/heroku/heroku-buildpack-php/compare/v190...v191
[v190]: https://github.com/heroku/heroku-buildpack-php/compare/v189...v190
[v189]: https://github.com/heroku/heroku-buildpack-php/compare/v188...v189
[v188]: https://github.com/heroku/heroku-buildpack-php/compare/v187...v188
[v187]: https://github.com/heroku/heroku-buildpack-php/compare/v186...v187
[v186]: https://github.com/heroku/heroku-buildpack-php/compare/v185...v186
[v185]: https://github.com/heroku/heroku-buildpack-php/compare/v184...v185
[v184]: https://github.com/heroku/heroku-buildpack-php/compare/v183...v184
[v183]: https://github.com/heroku/heroku-buildpack-php/compare/v182...v183
[v182]: https://github.com/heroku/heroku-buildpack-php/compare/v181...v182
[v181]: https://github.com/heroku/heroku-buildpack-php/compare/v180...v181
[v180]: https://github.com/heroku/heroku-buildpack-php/compare/v179...v180
[v179]: https://github.com/heroku/heroku-buildpack-php/compare/v178...v179
[v178]: https://github.com/heroku/heroku-buildpack-php/compare/v177...v178
[v177]: https://github.com/heroku/heroku-buildpack-php/compare/v176...v177
[v176]: https://github.com/heroku/heroku-buildpack-php/compare/v175...v176
[v175]: https://github.com/heroku/heroku-buildpack-php/compare/v174...v175
[v174]: https://github.com/heroku/heroku-buildpack-php/compare/v173...v174
[v173]: https://github.com/heroku/heroku-buildpack-php/compare/v172...v173
[v172]: https://github.com/heroku/heroku-buildpack-php/compare/v171...v172
[v171]: https://github.com/heroku/heroku-buildpack-php/compare/v170...v171
[v170]: https://github.com/heroku/heroku-buildpack-php/compare/v169...v170
[v169]: https://github.com/heroku/heroku-buildpack-php/compare/v168...v169
[v168]: https://github.com/heroku/heroku-buildpack-php/compare/v167...v168
[v167]: https://github.com/heroku/heroku-buildpack-php/compare/v166...v167
[v166]: https://github.com/heroku/heroku-buildpack-php/compare/v165...v166
[v165]: https://github.com/heroku/heroku-buildpack-php/compare/v164...v165
[v164]: https://github.com/heroku/heroku-buildpack-php/compare/v163...v164
[v163]: https://github.com/heroku/heroku-buildpack-php/compare/v162...v163
[v162]: https://github.com/heroku/heroku-buildpack-php/compare/v161...v162
[v161]: https://github.com/heroku/heroku-buildpack-php/compare/v160...v161
[v160]: https://github.com/heroku/heroku-buildpack-php/compare/v159...v160
[v159]: https://github.com/heroku/heroku-buildpack-php/compare/v158...v159
[v158]: https://github.com/heroku/heroku-buildpack-php/compare/v157...v158
[v157]: https://github.com/heroku/heroku-buildpack-php/compare/v156...v157
[v156]: https://github.com/heroku/heroku-buildpack-php/compare/v155...v156
[v155]: https://github.com/heroku/heroku-buildpack-php/compare/v154...v155
[v154]: https://github.com/heroku/heroku-buildpack-php/compare/v153...v154
[v153]: https://github.com/heroku/heroku-buildpack-php/compare/v152...v153
[v152]: https://github.com/heroku/heroku-buildpack-php/compare/v151...v152
[v151]: https://github.com/heroku/heroku-buildpack-php/compare/v150...v151
[v150]: https://github.com/heroku/heroku-buildpack-php/compare/v149...v150
[v149]: https://github.com/heroku/heroku-buildpack-php/compare/v148...v149
[v148]: https://github.com/heroku/heroku-buildpack-php/compare/v147...v148
[v147]: https://github.com/heroku/heroku-buildpack-php/compare/v146...v147
[v146]: https://github.com/heroku/heroku-buildpack-php/compare/v145...v146
[v145]: https://github.com/heroku/heroku-buildpack-php/compare/v144...v145
[v144]: https://github.com/heroku/heroku-buildpack-php/compare/v143...v144
[v143]: https://github.com/heroku/heroku-buildpack-php/compare/v142...v143
[v142]: https://github.com/heroku/heroku-buildpack-php/compare/v141...v142
[v141]: https://github.com/heroku/heroku-buildpack-php/compare/v140...v141
[v140]: https://github.com/heroku/heroku-buildpack-php/compare/v139...v140
[v139]: https://github.com/heroku/heroku-buildpack-php/compare/v138...v139
[v138]: https://github.com/heroku/heroku-buildpack-php/compare/v137...v138
[v137]: https://github.com/heroku/heroku-buildpack-php/compare/v136...v137
[v136]: https://github.com/heroku/heroku-buildpack-php/compare/v135...v136
[v135]: https://github.com/heroku/heroku-buildpack-php/compare/v134...v135
[v134]: https://github.com/heroku/heroku-buildpack-php/compare/v133...v134
[v133]: https://github.com/heroku/heroku-buildpack-php/compare/v132...v133
[v132]: https://github.com/heroku/heroku-buildpack-php/compare/v131...v132
[v131]: https://github.com/heroku/heroku-buildpack-php/compare/v130...v131
[v130]: https://github.com/heroku/heroku-buildpack-php/compare/v129...v130
[v129]: https://github.com/heroku/heroku-buildpack-php/compare/v128...v129
[v128]: https://github.com/heroku/heroku-buildpack-php/compare/v127...v128
[v127]: https://github.com/heroku/heroku-buildpack-php/compare/v126...v127
[v126]: https://github.com/heroku/heroku-buildpack-php/compare/v125...v126
[v125]: https://github.com/heroku/heroku-buildpack-php/compare/v124...v125
[v124]: https://github.com/heroku/heroku-buildpack-php/compare/v123...v124
[v123]: https://github.com/heroku/heroku-buildpack-php/compare/v122...v123
[v122]: https://github.com/heroku/heroku-buildpack-php/compare/v121...v122
[v121]: https://github.com/heroku/heroku-buildpack-php/compare/v120...v121
[v120]: https://github.com/heroku/heroku-buildpack-php/compare/v119...v120
[v119]: https://github.com/heroku/heroku-buildpack-php/compare/v118...v119
[v118]: https://github.com/heroku/heroku-buildpack-php/compare/v117...v118
[v117]: https://github.com/heroku/heroku-buildpack-php/compare/v116...v117
[v116]: https://github.com/heroku/heroku-buildpack-php/compare/v115...v116
[v115]: https://github.com/heroku/heroku-buildpack-php/compare/v114...v115
[v114]: https://github.com/heroku/heroku-buildpack-php/compare/v113...v114
[v113]: https://github.com/heroku/heroku-buildpack-php/compare/v112...v113
[v112]: https://github.com/heroku/heroku-buildpack-php/compare/v111...v112
[v111]: https://github.com/heroku/heroku-buildpack-php/compare/v110...v111
[v110]: https://github.com/heroku/heroku-buildpack-php/compare/v109...v110
[v109]: https://github.com/heroku/heroku-buildpack-php/compare/v108...v109
[v108]: https://github.com/heroku/heroku-buildpack-php/compare/v107...v108
[v107]: https://github.com/heroku/heroku-buildpack-php/compare/v106...v107
[v106]: https://github.com/heroku/heroku-buildpack-php/compare/v105...v106
[v105]: https://github.com/heroku/heroku-buildpack-php/compare/v104...v105
[v104]: https://github.com/heroku/heroku-buildpack-php/compare/v103...v104
[v103]: https://github.com/heroku/heroku-buildpack-php/compare/v102...v103
[v102]: https://github.com/heroku/heroku-buildpack-php/compare/v101...v102
[v101]: https://github.com/heroku/heroku-buildpack-php/compare/v100...v101
[v100]: https://github.com/heroku/heroku-buildpack-php/compare/v99...v100
[v99]: https://github.com/heroku/heroku-buildpack-php/compare/v98...v99
[v98]: https://github.com/heroku/heroku-buildpack-php/compare/v97...v98
[v97]: https://github.com/heroku/heroku-buildpack-php/compare/v96...v97
[v96]: https://github.com/heroku/heroku-buildpack-php/compare/v95...v96
[v95]: https://github.com/heroku/heroku-buildpack-php/compare/v94...v95
[v94]: https://github.com/heroku/heroku-buildpack-php/compare/v93...v94
[v93]: https://github.com/heroku/heroku-buildpack-php/compare/v92...v93
[v92]: https://github.com/heroku/heroku-buildpack-php/compare/v91...v92
[v91]: https://github.com/heroku/heroku-buildpack-php/compare/v90...v91
[v90]: https://github.com/heroku/heroku-buildpack-php/compare/v89...v90
[v89]: https://github.com/heroku/heroku-buildpack-php/compare/v88...v89
[v88]: https://github.com/heroku/heroku-buildpack-php/compare/v87...v88
[v87]: https://github.com/heroku/heroku-buildpack-php/compare/v86...v87
[v86]: https://github.com/heroku/heroku-buildpack-php/compare/v85...v86
[v85]: https://github.com/heroku/heroku-buildpack-php/compare/v84...v85
[v84]: https://github.com/heroku/heroku-buildpack-php/compare/v83...v84
[v83]: https://github.com/heroku/heroku-buildpack-php/compare/v82...v83
[v82]: https://github.com/heroku/heroku-buildpack-php/compare/v81...v82
[v81]: https://github.com/heroku/heroku-buildpack-php/compare/v80...v81
[v80]: https://github.com/heroku/heroku-buildpack-php/compare/v79...v80
[v79]: https://github.com/heroku/heroku-buildpack-php/compare/v78...v79
[v78]: https://github.com/heroku/heroku-buildpack-php/compare/v77...v78
[v77]: https://github.com/heroku/heroku-buildpack-php/compare/v76...v77
[v76]: https://github.com/heroku/heroku-buildpack-php/compare/v75...v76
[v75]: https://github.com/heroku/heroku-buildpack-php/compare/v74...v75
[v74]: https://github.com/heroku/heroku-buildpack-php/compare/v73...v74
[v73]: https://github.com/heroku/heroku-buildpack-php/compare/v72...v73
[v72]: https://github.com/heroku/heroku-buildpack-php/compare/v71...v72
[v71]: https://github.com/heroku/heroku-buildpack-php/compare/v70...v71
[v70]: https://github.com/heroku/heroku-buildpack-php/compare/v69...v70
[v69]: https://github.com/heroku/heroku-buildpack-php/compare/v68...v69
[v68]: https://github.com/heroku/heroku-buildpack-php/compare/v67...v68
[v67]: https://github.com/heroku/heroku-buildpack-php/compare/v66...v67
[v66]: https://github.com/heroku/heroku-buildpack-php/compare/v65...v66
[v65]: https://github.com/heroku/heroku-buildpack-php/compare/v64...v65
[v64]: https://github.com/heroku/heroku-buildpack-php/compare/v63...v64
[v63]: https://github.com/heroku/heroku-buildpack-php/compare/v62...v63
[v62]: https://github.com/heroku/heroku-buildpack-php/compare/v61...v62
[v61]: https://github.com/heroku/heroku-buildpack-php/compare/v60...v61
[v60]: https://github.com/heroku/heroku-buildpack-php/compare/v59...v60
[v59]: https://github.com/heroku/heroku-buildpack-php/compare/v58...v59
[v58]: https://github.com/heroku/heroku-buildpack-php/compare/v57...v58
[v57]: https://github.com/heroku/heroku-buildpack-php/compare/v56...v57
[v56]: https://github.com/heroku/heroku-buildpack-php/compare/v55...v56
[v55]: https://github.com/heroku/heroku-buildpack-php/compare/v54...v55
[v54]: https://github.com/heroku/heroku-buildpack-php/compare/v53...v54
