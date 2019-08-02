This directory is used by boot scripts as an additional config scan dir until the actual web server process is launched; it gets set (or appended) into `PHP_INI_SCAN_DIR`.

The purpose is to have directives in this config that should only apply during the various `php` and `composer` calls that happen before the actual web server process is launched.

The common use case is to prevent APM extensions such as new relic from instrumenting the many `php` and `composer` calls in boot scripts, and to avoid the associated startup messages from cluttering the logs.

The alternative approach, `php -n`, does not work, since many environments load even default extensions such as `ext-json` as shared libraries through their INIs, or otherwise would be stripped of necessary settings (e.g. a global `pcre.jit=0`, needed for Composer to work on certain platforms).
