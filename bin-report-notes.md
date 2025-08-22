## remaining to port from old implementation

### warnings

warnings.addons.blackfire.extension_missing => (warnings.)apm.blackfire.extension_missing = true
warnings.addons.newrelic.extension_missing => (warnings.)apm.newrelic.extension_mising = true
warnings.composer_json.missing => (warnings.)composer_json = "missing"
warnings.composer_json.empty => (warnings.)composer_json = "empty"
warnings.composer_lock.outdated => (warnings.)composer_lock = "outdated"
warnings.composer_lock.minimum_stability => (warnings.)composer_lock.minimum_stability = "$minimum_stability_value"
> convert thes below to an enum, or a relative date? do we even need to log this? the dates are "static" and we are recording the version series...
warnings.runtime_eol.eol_reached => (warnings.)platform.php.eol_reached
warnings.runtime_eol.eol_close => (warnings.)platform.php.eol_close
warnings.runtime_eol.eom_reached => (warnings.)platform.php.eom_reached
warnings.runtime_eol.eom_close => (warnings.)platform.php.eom_close
warnings.vendor_dir => (warnings.)vendor_dir.present = true

### errors

failures.platform.solving.$(detect_platform_solving_failures <<< "$install_log") => failure_reason = platform.solving.<<<...
failures.platform.install.$(detect_platform_install_failures <<< "$install_log") => failure_reason = platform.install.<<<...
failures.dependencies.solving.$(detect_dependencies_solving_failures < "$install_log") => failure_reason = dependencies.solving.<<<...
failures.dependencies.install.$(detect_dependencies_install_failures < "$install_log") => failure_reason = dependencies.solving.<<<...

### planned removals

- SYMFONY_ENV etc warnings (just not possible to keep up)
- special cased extensions

### failures.sh

- we need the ability to capture matches from the regex into the resulting warning value
- for errors, we want to capture the reason
- for warnings, we want to capture each warning

## ideas/questions

- somehow... what missing platform package was the reason
	- there can be different reasons...
		- "could not be found in any version"
		- "no matching package found"
	- there can be multiple packages...
		- log as sorted array of package names?
- on Composer dependency installation or script failure, can we get the exception name?
- any env vars where we should track when they are set?
- can/should we track platform.dependencies.count and dependencies.count separately for direct and indirect depencencies, is there any point?
	- probably not until intermediate "composer.json/composer.lock" package is removed (already gone in CNB)
- should we log cache size?
	- should we GC manually? Composer randomly does it for every ~50 builds via `!random_int(0, 50)`

## new stuff to log

- record if there are no (none or only indirect) php requires
- log value of COMPOSER env var (composer_json.name)
- log whether custom repo URL is used (platform.repositories.custom_url.count)
	- and whether it's re-set entirely
- log whether platform repo snapshot is used (platform.repositories.default.snapshot as string)
	- HEROKU_PHP_PLATFORM_REPOSITORY_SNAPSHOT_FALLBACK
- platform API version from composer_lock
- ext-newrelic version if auto-installed?
- ext-blackfire version if auto-installed?

## new stuff that needs other changes

- call stack from err_trap
	- there is branch work to have that function in subshells - we can use the presence of the key in the store as the "has been printed" marker!
- record if people are pinning php: composer show -f json --strict --outdated --patch-only heroku-sys/php
	- returns 1 if outdated
	- then run composer why-not heroku-sys/php $(^^ | jq -r '.latest')

## special test todos

- grepping of messages from Composer for different supported versions?
