These folders contain run-time configs for HTTPD, Nginx and PHP.

The logic that finds these looks in the base directory first, and then traverses into sub-folders that represent specific version string parts.

This allows sharing configs between version series, but also overriding (or adding) files for more specific versions, as they take precedence.

For example, a general `php/php-fpm.conf` can be overridden for PHP 8.* by having a `php/8/php-fpm.conf`; a file that should only apply to PHP 7.3.* without overriding a "parent" could be put into `php/7/3/php-fpm.somepool.conf`.
