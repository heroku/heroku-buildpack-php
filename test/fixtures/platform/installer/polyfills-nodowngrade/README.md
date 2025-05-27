This test case asserts that a native extension install attempt for a polyfilled extension will not change existing locked dependencies.

It used to test using `ext-xmlrpc`, which was only bundled with PHP 7. The initial `"php": "*"` requirement would pick PHP 8 (which no longer had `ext-xmlrpc`) due to an available polyfill for it, and we don't want to downgrade PHP to version 7 once the `ext-xmlrpc.native` install attempt is made.

We don't have PHP 7 anymore, and the only recently retired extension is `ext-imap` (since PHP 8.4), but that is available through PECL and we offer it, so we have to use specific versions of extensions. A suitable candidate therefore is `ext-newrelic`, which is only available in version 11 for PHP 8.4, so our polyfill provides `ext-newrelic` version 10, and `composer.json` also depends on version 10.
