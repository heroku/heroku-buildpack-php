Userland "polyfill" packages (e.g. `symfony/polyfill-mbstring`) can declare a native extension as "provided". If a user has such a polyfill in their dependency graph (and they often do, since other packages use these polyfills), then during dependency resolution, the "real" extension package (which we rewrite to e.g. `heroku-sys/ext-mbstring`) will not be installed, since another, installed, package (`symfony/polyfill-mstring`) already fulfills the requirement (via its `provide` metadata field).

But our platform package installation logic must

1. ensure that if extension Foo depends on extension Bar (e.g. `ext-pq` needs `ext-raphf`), then extension Bar must not come from a userland polyfill - extension Foo needs symbols from the "real", native C extension, not a userland PHP implementation whose internal functions it cannot even call;
2. attempt, after the first "wave" of userland installs is complete, to install the native extension after all, to ensure maximum compatibility and performance.

To do this, all of our extensions in their Composer package metadata "replace" themselves a with package that has a suffix of "`.native`" appended to the name. So an `ext-raphf` declares a `replace` entry for `ext-raphf.native`.

Other native extensions can then depend on this; so `ext-pq` will say that it requires `ext-raphf` and `ext-raphf.native`, to ensure point 1) above.

The platform packages installation logic will then, after the first "wave" of userland installs is complete (where e.g. `ext-mbstring` wasn't installed, because `symfony/polyfill-mbstring` was there), attempt to explicitly require `ext-mbstring.native` etc, in order to try and force native extensions. This will not always succeed (e.g. in cases where the extension is no longer available for that PHP version series), but that's okay.

The entire generation of "`.native`" entries in `replace` and `require`, throughout all packages, is done in `mkrepo.sh` (so individual package formulae do not have to know or worry about any of this), and this test case explicitly tests a few of these combinations:

- regular extensions
- shared extensions bundled with PHP
- statically compiled extensions bundled with PHP
- backwards compatibility with older package metadata files in a repository that still explicitly set a "`.native`" requirement or replacement (the `php-7.4.22.composer.json` case)
