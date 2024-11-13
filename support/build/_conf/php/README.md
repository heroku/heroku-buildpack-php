Our builds of PHP use the recommended `php.ini-production` file from the respective release.

These values are often different from the built-in default, and for a subset of settings, we want to override them. Examples include the default timezone (which is unset by default and in the recommended configs), errir reporting level (we want users to see deprecation warnings), or session ID length (which for legacy reasons defaults to 26 in the recommended development and production INI files, even though PHP's built-in default is 32).

Doing this using a `conf.d` file allows our settings to apply even if users bring their own "full" `php.ini` (and we can just copy these in without having to track possible upstream INI changes).
