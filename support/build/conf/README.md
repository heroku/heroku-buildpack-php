These folders contain build-time configs for HTTPD and PHP.

The logic that finds these looks in the base directory first, and then traverses into sub-folders that represent specific version string parts.

This allows sharing configs between version series, but also overriding (or adding) files for more specific versions, as they take precedence.

For example, a general `php/conf.d/000-heroku.ini` can be overridden for PHP 7.* by having a `php/7/conf.d/000-heroku.ini`; a file that should only apply to PHP 8.0.* without overriding a "parent" could be put into `php/8/0/conf.d/001-foobar.ini`.
