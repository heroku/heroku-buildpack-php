## all keys, in order

bootstrap.duration
platform.prepare.duration
platform.install.main.duration        - platform.dependencies.install.duration
platform.install.main.packages.installed_count # includes Composer and web servers on Classic
platform.install.polyfills.duration   - platform.polyfills.install.duration
platform.install.polyfills.packages.attempted_count
platform.install.polyfills.packages.succeeded_count
platform.install.polyfills.packages.unavailable = []
platform.install.polyfills.packages.installed_count
platform.install.composer.duration # CNB only
platform.install.composer.packages.installed_count # CNB only
platform.install.webservers.duration # CNB only
platform.install.webservers.packages.installed_count # CNB only
platform.install.duration
platform.packages.installed_count # this includes polyfills...
platform.php.version
platform.php.series
dependencies.install.duration
dependencies.packages.installed_count - dependencies.count
scripts.compile.duration
apm.automagic.duration
duration

## prior and related measurements

### moved

platform.count => platform.dependencies.count
platform.packages.php.$(php -r "echo PHP_VERSION;") => platform.php.version
(new) => platform.php.series

dependencies.count => dependencies.count

### remaining

warnings.addons.blackfire.extension_missing => (warnings.)apm.blackfire.extension_missing = true
warnings.addons.newrelic.extension_missing => (warnings.)apm.newrelic.extension_mising = true
failures.addons.newrelic.NEW_RELIC_CONFIG_FILE => failure_reason = apm.newrelic.NEW_RELIC_CONFIG_FILE.missing
failures.composer_json.lint => failure_reason = composer_json.lint
failures.composer_lock.missing => failure_reason = composer_lock.missing
failures.composer_lock.lint => failure_reason = composer_lock.lint
warnings.composer_json.missing => (warnings.)composer_json.missing
warnings.composer_json.empty => (warnings.)composer_json.empty
failures.platform.slug_as_source => failure_reason = platform.slug_as_source
failures.bootstrap.download.php-min => failure_reason = bootstrap.php-min.download
failures.bootstrap.download.composer => failure_reason = bootstrap.composer.download
warnings.composer_lock.outdated => (warnings.)composer_lock.outdated
warnings.composer_lock.minimum_stability => (warnings.)composer_lock.minimum_stability
failures.platform.composer_lock.runtime_only_in_dev => failure_reason = (platform.)composer_lock.runtime_only_in_dev
failures.platform.repositories.custom_url.invalid => failure_reason = platform.repositories.custom_url.invalid
failures.platform.composer_lock.parse => failure_reason = (platform.)composer_lock.parse

failures.platform.solving.$(detect_platform_solving_failures <<< "$install_log") => failure_reason = platform.solving.<<<...
failures.platform.install.$(detect_platform_install_failures <<< "$install_log") => failure_reason = platform.install.<<<...

warnings.runtime_eol.eol_reached => (warnings.)platform.php.eol_reached
warnings.runtime_eol.eol_close => (warnings.)platform.php.eol_close
warnings.runtime_eol.eom_reached => (warnings.)platform.php.eom_reached
warnings.runtime_eol.eom_close => (warnings.)platform.php.eom_close
warnings.vendor_dir => (warnings.)vendor_dir.present

failures.dependencies.auth.COMPOSER_GITHUB_OAUTH_TOKEN => failure_reason = env.COMPOSER_GITHUB_OAUTH_TOKEN.auth_failed

failures.dependencies.solving.$(detect_dependencies_solving_failures < "$install_log") => failure_reason = dependencies.solving.<<<...
failures.dependencies.install.$(detect_dependencies_install_failures < "$install_log") => failure_reason = dependencies.solving.<<<...

failures.dependencies.buildpack_as_dependency => failure_reason = dependencies.buildpack_as_dependency
failures.compile_step => failure_reason = scripts.compile.exception or scripts.compile.error

## ideas/questions

- somehow... what missing platform package was the reason
  - there can be different reasons...
    - "could not be found in any version"
    - "no matching package found"
  - there can be multiple packages...
    - log as sorted array of package names
- on Composer dependency installation or script failure, can we get the exception name?
- any env vars where we should track when they are set?
- can/should we track platform.dependencies.count and dependencies.count separately for direct and indirect depencencies, is there any point?
  - probably not until intermediate "composer.json/composer.lock" package is removed (already gone in CNB)
- can we log userland cache hits?
- should we log cache size?

## failures.sh

- we need the abilityto capture matches from the regex into the resulting warning value
- for errors, we want to capture the reason
- for warnings, we want to capture each warning

## new stuff to log

- timings!
- record if there are no (none or only indirect) php requires
- log value of COMPOSER env var (composer_json.name)
- log whether custom repo URL is used (platform.repositories.custom_url.count)
- log whether platform repo snapshot is used (platform.repositories.default.snapshot as string)
- HEROKU_PHP_PLATFORM_REPOSITORY_SNAPSHOT_FALLBACK
- platform API version from composer_lock
- ext-newrelic version if auto-installed
- ext-blackfire version if auto-installed

## new stuff that needs other changes

- call stack from err_trap
  - there is branch work to have that function in subshells - we can use the presence of the key in the store as the "has been printed" marker!
- record if people are pinning php: composer show -f json --strict --outdated --patch-only heroku-sys/php
  - returns 1 if outdated
  - then run composer why-not heroku-sys/php $(^^ | jq -r '.latest')

## special test todos

- grepping of messages from Composer for different supported versions?

## planned removals

- SYMFONY_ENV etc warnings (just not possible to keep up)
- special cased extensions
