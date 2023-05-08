Our PHP packages are named "php", and versioned "7.4.0", "8.0.9", and so forth.

Each extension, say "ext-redis", has a release version, say "5.1.2", but gets compiled for each PHP version series.

As a result, there are multiple packages named "ext-redis" with version "5.1.2", pointing to different tarballs
each of these packages' Composer package metadata lists the respective PHP version series as a dependency in its "require" section, e.g. `"php": "8.0.*"` or `"php": "7.4.*"`

Composer's dependency solver supports multiple packages with the same name and version inside a repository, but to keep complexity manageable, it will pick the first packages that satisfy the given version range requirements, and "stick" to them, even if for some selected packages, a different combination with higher version numbers might be resolvable.

This is never a problem in "real life" for user-land dependencies, because no package there can exist multiple times with the same name and version, but different requirements inside.

We do however need this for extensions, and if a user's requirements have no specific bounds (e.g. the user requires `"php":">=7.0.0"` and `"ext-redis":"*"`), an edge case might be triggered.

In this particular situation, a user would get PHP 8 and ext-redis.

However, if a user lists `"ext-redis":"*"` first, and `"php":">=7.0.0"` second, and the repository lists the "ext-redis" package for PHP 7.4.* before the "ext-redis" package for PHP 8.0.*, a user will get PHP 7.4 installed instead of PHP 8.0.

If the repository however lists the "ext-redis" package for PHP 8.0.* first, a user will get PHP 8.0 installed instead; that's why `mkrepo.sh` re-orders extension packages to be in descending order of PHP series they are compiled for, to ensure that users always get the highest possible PHP version that also satisfies all other requirements.

For this test case, shell glob expansion means `mkrepo.sh` will receive the `*.composer.json` file arguments in alnum order, so our PHP 7.4 extension package metadata file will be handed in before the PHP 8.0 extension one, but in our expected result, the 8.0 extension is listed first.
