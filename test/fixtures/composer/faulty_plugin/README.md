This fixture contains a Composer plugin that prints to stdout during activation.

Because we read the output of various Composer commands such as `composer config` or `composer show -f json`, this would cause problems unless those command invocations explicitly specified `--no-plugins`.

By having this test fixture's dummy plugin misbehave in the manner above, we can test that all relevant calls do so (both during build and during dyno boot).
