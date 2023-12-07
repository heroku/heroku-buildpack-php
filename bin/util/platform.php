#!/usr/bin/env php
<?php

$COMPOSER = getenv("COMPOSER")?:"composer.json";
$COMPOSER_LOCK = getenv("COMPOSER_LOCK")?:"composer.lock";
$STACK = getenv("STACK")?:"heroku-22";

// prefix keys with "heroku-sys/"
function mkdep($require) { return array_combine(array_map(function($v) { return "heroku-sys/$v"; }, array_keys($require)), $require); }
// check if require section demands a runtime
function hasreq($require) { return isset($require["php"]); }

// return stability flag string for Composer's internal numeric value from lock file
function getflag($number) {
	static $stabilityFlags = [
		0  => "stable",
		5  => "RC",
		10 => "beta",
		15 => "alpha",
		20 => "dev",
	];
	if(!isset($stabilityFlags[$number])) {
		file_put_contents("php://stderr", "ERROR: invalid stability flag '$number' in $COMPOSER_LOCK");
		exit(1);
	}
	return "@".$stabilityFlags[$number];
}

function mkmetas($package, array &$metapaks, &$have_runtime_req = false) {
	// filter platform packages - only "php", "php-64bit", and "ext-foobar" (but not "ext-foobar.native")
	$platfilter = function($v) { return preg_match("#^(php(-64bit)?$|ext-.+(?<!\.native)$)#", $v); };
	
	// extract only platform requires, replaces and provides
	$preq = array_filter(isset($package["require"]) ? $package["require"] : [], $platfilter, ARRAY_FILTER_USE_KEY);
	$prep = array_filter(isset($package["replace"]) ? $package["replace"] : [], $platfilter, ARRAY_FILTER_USE_KEY);
	$ppro = array_filter(isset($package["provide"]) ? $package["provide"] : [], $platfilter, ARRAY_FILTER_USE_KEY);
	$pcon = array_filter(isset($package["conflict"]) ? $package["conflict"] : [], $platfilter, ARRAY_FILTER_USE_KEY);
	if(!$preq && !$prep && !$ppro && !$pcon) return false;
	$have_runtime_req |= hasreq($preq);
	$metapaks[] = [
		"type" => "metapackage",
		// we re-use the dep name and version, makes for nice error messages if dependencies cannot be fulfilled :)
		"name" => $package["name"],
		"version" => $package["version"],
		"require" => (object) mkdep($preq),
		"replace" => (object) mkdep($prep),
		"provide" => (object) mkdep($ppro),
		"conflict" => (object) mkdep($pcon),
	];
	return true;
}

// parse options/flags, then advance $argv pointer (to skip $0, too)
$flags = getopt("", ["list-repositories"], $rest_index);
$argv = array_slice($argv, $rest_index);

// base repos we need - no packagist, and the installer plugin path (first arg)
$repositories = [
	["packagist" => false],
	["type" => "path", "url" => array_shift($argv), "options" => ["symlink" => false]],
];
// little helper for prefixing extension names filtered in repositories below with the correct "heroku-sys/"
$prefixExtname = function($value) {
	$value = trim($value);
	return strpos($value, "/") === false ? "heroku-sys/$value" : $value;
};
if(!count($argv)) {
	file_put_contents("php://stderr", "ERROR: no platform repositories given; aborting.\n");
	exit(4);
}
if(isset($flags['list-repositories'])) {
	file_put_contents("php://stderr", "\033[1;33mNOTICE:\033[0m Platform repositories used (in lookup order):\n");
}
// all other args are repo URLs; they get passed in ascending order of precedence, so we reverse
foreach(array_reverse($argv) as $repo) {
	$url = parse_url($repo);
	if(!$url || !isset($url["scheme"]) || !isset($url["host"])) {
		file_put_contents("php://stderr", "ERROR: could not parse platform repository URL '$repo'.\n");
		exit(4);
	}
	if(isset($flags['list-repositories'])) {
		file_put_contents(
			"php://stderr",
			sprintf(
				"- %s://%s%s%s\n", # hide auth info and query args
				$url["scheme"],
				$url["host"],
				isset($url["port"]) ? ":".$url["port"] : "",
				$url["path"]??"/"
			)
		);
	}
	$repo = ["type" => "composer", "url" => $repo];
	// allow control of https://getcomposer.org/doc/articles/repository-priorities.md via query args "composer-repository-canonical", "composer-repository-exclude" and "composer-repository-only"
	if(isset($url["query"])) {
		parse_str($url["query"], $query); // parse query string into array
		if(isset($query["composer-repository-canonical"])) {
			$repo["canonical"] = filter_var($query["composer-repository-canonical"], FILTER_VALIDATE_BOOLEAN);
		}
		if(isset($query["composer-repository-exclude"])) {
			$repo["exclude"] = array_map(
				$prefixExtname, // add "heroku-sys/" prefix to entries
				is_array($query["composer-repository-exclude"]) ? $query["composer-repository-exclude"] : explode(",", $query["composer-repository-exclude"])
			);
		}
		if(isset($query["composer-repository-only"])) {
			$repo["only"] = array_map(
				$prefixExtname, // add "heroku-sys/" prefix to entries
				is_array($query['composer-repository-only']) ? $query["composer-repository-only"] : explode(",", $query["composer-repository-only"])
			);
		}
	}
	
	$repositories[] = $repo;
}

$json = json_decode(file_get_contents($COMPOSER), true);
if(!is_array($json)) exit(1);

$have_runtime_req = false;
$have_dev_runtime_req = false;
$require = [];
$requireDev = [];
if(file_exists($COMPOSER_LOCK)) {
	$lock = json_decode(file_get_contents($COMPOSER_LOCK), true);
	// basic lock file validity check
	if(!$lock || !isset($lock["platform"], $lock["platform-dev"], $lock["packages"], $lock["packages-dev"])) exit(1);
	if(!isset($lock["content-hash"]) && !isset($lock["hash"])) exit(1);
	$have_runtime_req |= hasreq($lock["platform"]);
	$have_dev_runtime_req |= hasreq($lock["platform-dev"]);
	// for each package that has platform requirements we build a meta-package that we then depend on
	// we cannot simply join all those requirements together with " " or "," because of the precedence of the "|" operator: requirements "5.*," and "^5.3.9|^7.0", which should lead to a PHP 5 install, would combine into "5.*,^5.3.9|^7.0" (there is no way to group requirements), and that would give PHP 7
	$metapaks = [];
	// whatever is in the lock "platform" key will be turned into a meta-package too, named "composer.json/composer.lock"; same for "platform-dev"
	// this will result in an installer event for that meta-package, from which we can extract what extensions that are bundled (and hence "replace"d) with the runtime need to be enabled
	// if we do not do this, then a require for e.g. ext-curl or ext-mbstring in the main composer.json cannot be found by the installer plugin
	$root = [
		"name" => "$COMPOSER/$COMPOSER_LOCK",
		"version" => "dev-".($lock["content-hash"] ?? $lock['hash']),
		"require" => $lock["platform"],
	];
	$rootDev = [
		"name" => "$COMPOSER/$COMPOSER_LOCK-require-dev",
		"version" => "dev-".($lock["content-hash"] ?? $lock['hash']),
		"require" => $lock["platform-dev"],
	];
	// inject the root meta-packages into the read lock file so later code picks them up too
	if($root["require"]) {
		$lock["packages"][] = $root;
		$require = [
			$root["name"] => $root["version"],
		];
		$sfr = [];
		// for any root platform require with implicit or explicit stability flags we must create a dummy require for that flag in the new root
		// the reason is that the actual requiring of the package version happens in the "composer.json/composer.lock" metapackage, but stability flags that allow e.g. an RC install are ignored there - they only take effect in the root "require" section so that dependencies don't push unstable stuff onto users
		foreach($lock["platform"] as $name => $version) {
			if(isset($lock["stability-flags"][$name])) {
				$sfr[$name] = getflag($lock["stability-flags"][$name]);
			}
		}
		$require = array_merge($require, mkdep($sfr));
	}
	// same for platform-dev requirements, but they go into a require-dev section later, so only installs with --dev pull those in
	if($rootDev["require"]) {
		$lock["packages-dev"][] = $rootDev;
		$requireDev = [
			$rootDev["name"] => $rootDev["version"],
		];
		$sfr = [];
		// for any root platform require-dev with implicit or explicit stability flags we must create a dummy require-dev for that flag in the new root
		// the reason is that the actual requiring of the package version happens in the "composer.json/composer.lock" metapackage, but stability flags that allow e.g. an RC install are ignored there - they only take effect in the root "require-dev" section so that dependencies don't push unstable stuff onto users
		foreach($lock["platform-dev"] as $name => $version) {
			if(isset($lock["stability-flags"][$name])) {
				$sfr[$name] = getflag($lock["stability-flags"][$name]);
			}
		}
		$requireDev = array_merge($requireDev, mkdep($sfr));
	}
	
	// collect platform requirements from regular packages in lock file
	foreach($lock["packages"] as $package) {
		if(mkmetas($package, $metapaks, $have_runtime_req)) {
			$require[$package["name"]] = $package["version"];
		}
	}
	// collect platform requirements from dev packages in lock file
	foreach($lock["packages-dev"] as $package) {
		if(mkmetas($package, $metapaks, $have_dev_runtime_req)) {
			$requireDev[$package["name"]] = $package["version"];
		}
	}
	
	// add all meta-packages to one local package repo
	if($metapaks) $repositories[] = ["type" => "package", "package" => $metapaks];
} else {
	// default to using Composer 2 if there is no lock file
	$lock["plugin-api-version"] = "2.2.0";
}

// if no PHP is required anywhere, we need to add something
if(!$have_runtime_req) {
	if($have_dev_runtime_req) {
		// there is no requirement for a PHP version in "require", nor in any dependencies therein, but there is one in "require-dev"
		// that's problematic, because requirements in there may effectively result in a rule like "8.0.*", but we'd next write "^7.0.0" into our "require" to have a sane default for all stacks, and that'd blow up in CI where dev dependenies are installed
		// we can't compute a resulting version rule (that's the whole point of the custom installer that uses Composer's solver), so throwing an error is the best thing we can do here
		exit(3);
	}
	file_put_contents("php://stderr", "\033[1;33mNOTICE:\033[0m No runtime required in $COMPOSER_LOCK; using PHP ". ($require["heroku-sys/php"] = getenv("HEROKU_PHP_DEFAULT_RUNTIME_VERSION") ?: "*") . "\n");
} elseif(!isset($root["require"]["php"])) {
	file_put_contents("php://stderr", "\033[1;33mNOTICE:\033[0m No runtime required in $COMPOSER; requirements\nfrom dependencies in $COMPOSER_LOCK will be used for selection\n");
}

// we want the latest Composer...
$require["heroku-sys/composer"] = "*";
// ... that supports the major plugin API version from the lock file (which corresponds to the Composer version series, so e.g. all 2.3.x releases have 2.3.0)
// if the lock file says "2.99.0", we generally still want to select "^2", and not "^2.99.0"
// this is so the currently available Composer version can install lock files generated by brand new or pre-release Composer versions, as this stuff is generally forward compatible
// otherwise, builds would fail the moment e.g. 2.6.0 comes out and people try it, even though 2.5 could install the project just fine
$pav = $lock["plugin-api-version"] ?? false;
if($pav === false) {
	file_put_contents("php://stderr", "\033[1;33mNOTICE:\033[0m No Composer plugin-api-version recorded in $COMPOSER_LOCK; file must be very old. Will attempt to use Composer 1 for installation.\n");
	$pav = "1.0.0";
}
if(in_array($pav, ["2.0.0", "2.1.0", "2.2.0"])) {
	// no rule without an exception, of course:
	// there are quite a lot of BC breaks for plugins in Composer 2.3
	// if the lock file was generated with 2.0, 2.1 or 2.2, we play it safe and install 2.2.x (which is LTS)
	// this is mostly to ensure any plugins that have an open enough version selector do not break with all the 2.3 changes
	// also ensures plugins are compatible with other libraries Composer bundles (e.g. various Symfony components), as those got big version bumps in 2.3
	$cpaRequire = "~2.2.0";
} else {
	$cpaRequire = "^".explode(".", $pav)[0]; // just "^2" or similar so we get the latest we have, see comment earlier
}
$require["heroku-sys/composer-plugin-api"] = $cpaRequire;

$require["heroku-sys/apache"] = "^2.4.10";
$require["heroku-sys/nginx"] = "^1.8.0";

preg_match("#^([^-]+)(?:-([0-9]+))?\$#", $STACK, $stack);
$provide = ["heroku-sys/".$stack[1] => (isset($stack[2])?$stack[2]:"1").gmdate(".Y.m.d")]; # heroku: 20.2021.02.04 etc

$replace = [];
// check whether the blackfire CLI is already there (from their https://github.com/blackfireio/integration-heroku buildpack)
exec("blackfire --no-ansi version 2>/dev/null", $blackfire_version, $have_blackfire);
if($have_blackfire === 0 && preg_match("/^Blackfire version (\d+\.\d+\.\d+)/", $blackfire_version[0], $matches)) {
	// and if so, "replace" it, so that we don't install our version - a "provide" would lead the solver to prefer a "real" package instead at least in Composer 1
	$replace["heroku-sys/blackfire"] = $matches[1];
	file_put_contents("php://stderr", "\033[1;33mNOTICE:\033[0m Blackfire CLI version $matches[1] detected.\n");
} elseif($have_blackfire === 0) {
	file_put_contents("php://stderr", "\033[1;33mWARNING:\033[0m Blackfire CLI detected, but could not determine version - falling back to bundled package!\n");
}

$json = [
	"config" => [
		"cache-files-ttl" => 0,
		"discard-changes" => true,
		"allow-plugins" => [
			"heroku/installer-plugin" => true
		],
	],
	"minimum-stability" => isset($lock["minimum-stability"]) ? $lock["minimum-stability"] : "stable",
	"prefer-stable" => isset($lock["prefer-stable"]) ? $lock["prefer-stable"] : false,
	"provide" => $provide,
	"replace" => (object) $replace,
	"require" => $require,
	// only write out require-dev if we're installing in CI, as indicated by the HEROKU_PHP_INSTALL_DEV set (to an empty string)
	"require-dev" => getenv("HEROKU_PHP_INSTALL_DEV") === false ? (object)[] : (object)$requireDev,
	// put require before repositories, or a large number of metapackages from above will cause Composer's regexes to hit PCRE limits for backtracking or JIT stack size
	"repositories" => $repositories,
];
echo json_encode($json, JSON_PRETTY_PRINT);
