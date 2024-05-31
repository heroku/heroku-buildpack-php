#!/usr/bin/env php
<?php

use Composer\Semver\Comparator;

require('vendor/autoload.php');

// sections to generate, but also some other stuff, can be passed via options
$sections = getopt('d:s:p:', ['strict', 'runtimes', 'built-in-extensions', 'third-party-extensions', 'composers', 'webservers'], $restIndex);
$posArgs = array_slice($argv, $restIndex);

$strict = isset($sections['strict']);
unset($sections['strict']);

// allow overriding of current date for EOL computation, useful for testing
$currentUnixTimestamp = strtotime($sections['d'] ?? 'now');
unset($sections['d']);

// allow overriding of stacks, useful for testing
if(isset($sections['s'])) {
	$stacks = explode(',', $sections['s']);
	unset($sections['s']);
	$stacks = array_combine(range(1, count($stacks)), $stacks); // re-index to start at 1, relevant for the numbering of footnotes
} else {
	// these need updating from time to time to add new stacks and remove EOL ones
	$stacks = [
		1 => '20', // the offset we start with here is relevant for the numbering of footnotes
		'22',
		'24',
	];
}

// allow overriding of PHP series, useful for testing
if(isset($sections['p'])) {
	$series = explode(',', $sections['p']);
	unset($sections['p']);
} else {
	// these need updating from time to time to add new series and remove series no longer on any stack
	$series = [
		'7.3',
		'7.4',
		'8.0',
		'8.1',
		'8.2',
		'8.3',
	];
}

$findstacks = function(array $package) use($stacks) {
	if($package['require']) {
		if(isset($package['require']['heroku-sys/heroku'])) {
			return Composer\Semver\Semver::satisfiedBy($stacks, $package['require']['heroku-sys/heroku']);
		}
	}
	// if there are no requirements specified for heroku-sys/heroku, this will match all stacks
	fprintf(STDERR, "NOTICE: package %s (version %s) has no 'require' entry for 'heroku-sys/heroku' and may get resolved for any stack.\n", $package['name'], $package['version']);
	return $stacks;
};

$findseries = function(array $package) use($series, $strict) {
	if($package['require']) {
		if(isset($package['require']['heroku-sys/php'])) {
			return Composer\Semver\Semver::satisfiedBy($series, $package['require']['heroku-sys/php']);
		}
	}
	// if there are no requirements specified for heroku-sys/php, this will match all PHP series (good luck with that, but rules are rules)
	fprintf(STDERR, "WARNING: package %s (version %s) has no 'require' entry for 'heroku-sys/php' and may get resolved for any PHP series!\n", $package['name'], $package['version']);
	if($strict) {
		fputs(STDERR, "ERROR: now aborting due to strict mode\n");
		exit(1);
	}
	return $series;
};

$stackname = function($version) {
	return "heroku-$version";
};

$filterStackVersions = function(array $row, string $serie, array $stacks, array $seriesByStack, callable $getValue) {
	$versions = [];
	foreach($stacks as $index => $stack) {
		$value = $getValue($row, $serie, $stack);
		if($value !== null) {
			$versions[$value][$index] = $stack;
		}
	}
	foreach($versions as &$version) {
		$version = array_diff($stacks, $version);
		$version = array_filter($version, function($stack) use($serie, $seriesByStack) { return isset($seriesByStack[$stack]) && in_array($serie, $seriesByStack[$stack]); });
	}
	return $versions;
};

$getBuiltinExtensionUrl = function($name) {
	$name = str_replace("heroku-sys/ext-", "", $name);
	switch(strtolower($name)) {
		case "bz2":
			$name = "bzip2";
			break;
		case "mysql":
			return "http://php.net/manual/en/book.mysql.php";
		case "zend-opcache":
			$name = "opcache";
			break;
	}
	return "http://php.net/$name";
};

$handlerStack = GuzzleHttp\HandlerStack::create(new GuzzleHttp\Handler\CurlHandler());
$handlerStack->push(GuzzleHttp\Middleware::retry(function($times, $req, $res, $e) {
	if($times >= 5) return false; // php.net sometimes randomly doesn't cooperate
	if($e instanceof GuzzleHttp\Exception\ConnectException) return true;
	if($res && $res->getStatusCode() >= 500) return true;
	return false;
}));
$client = new GuzzleHttp\Client(['handler' => $handlerStack, "timeout" => "2.0"]);

$repositories = [];
$responses = GuzzleHttp\Pool::batch($client, (function() use($posArgs, $client) {
	foreach($posArgs as $arg) {
		yield function() use($client, $arg) {
			if(file_exists($arg)) { // for local files
				return new GuzzleHttp\Psr7\Response(200, [], file_get_contents($arg));
			} else {
				return $client->getAsync($arg);
			}
		};
	}
})(), [
	'concurrency' => 5,
	'rejected' => function($reason) {
		throw $reason;
	},
	'fulfilled' => function($response, $index) use(&$repositories, $posArgs) {
		if(!($repositories[] = json_decode($response->getBody(), true))) {
			throw new Exception('Could not decode JSON for ' . $posArgs[$index]);
		}
	},
]);

// load EOL info from bin/util/eol.php
$eol = array_filter(array_map(function($eolDates) use($currentUnixTimestamp) {
	if(strtotime($eolDates[1]) < $currentUnixTimestamp)
		return "eol";
	elseif(strtotime($eolDates[0]) < $currentUnixTimestamp)
		return "security";
	else
		return null; // will be removed by array_filter
}, include(__DIR__ . "/../../bin/util/eol.php")));

$packages = [];
foreach($repositories as $repository) {
	foreach($repository['packages'] as $packageName => $packageVersions) {
		$packages = array_merge($packages, $packageVersions);
	}
}

$db = new SQLite3(':memory:');
$db->createCollation('VERSION_CMP', 'version_compare'); // for sorting/MAXing versions; we have to use it explicitly inside MAX(CASE…) statements in addition to setting it on the version column
$db->exec("CREATE TABLE packages (name TEXT COLLATE NOCASE, version TEXT COLLATE VERSION_CMP, type TEXT, series TEXT COLLATE VERSION_CMP, stack TEXT)");
$db->exec("CREATE TABLE extensions (name TEXT COLLATE NOCASE, url TEXT, version TEXT COLLATE VERSION_CMP, runtime TEXT, series TEXT COLLATE VERSION_CMP, stack TEXT, bundled INTEGER DEFAULT 0, enabled INTEGER DEFAULT 1)");
$insertPackage = $db->prepare("INSERT INTO packages (name, version, type, series, stack) VALUES(:name, :version, :type, :series, :stack)");
$insertExtension = $db->prepare("INSERT INTO extensions (name, url, version, runtime, series, stack, bundled, enabled) VALUES(:name, :url, :version, :runtime, :series, :stack, :bundled, :enabled)");

foreach($packages as $package) {
	if($package['type'] == 'heroku-sys-php-extension') {
		// for extensions, we want to find the stack(s) and PHP version series (always just one due to extension API version) that match the "require" entries in the extension package's metadata, and then generate an entry for each permutation
		// example: an extension is for heroku-sys/php:8.3.* and for heroku-sys/heroku:*, then we want two entires, both for series 8.3, but one for heroku-20 and one for heroku-22 (or whatever stacks are current)
		foreach($findstacks($package) as $stack) {
			// check whether it's a regular extension, or one bundled with PHP but not compiled in (those have that special dist type)
			// bundled and compiled in extensions do not get separate package entries, but are only declared in the "replace" list of their PHP release entry
			$isBundled = isset($package['dist']['type']) && $package['dist']['type'] == 'heroku-sys-php-bundled-extension';
			if($isBundled) {
				// bundled extensions have the exact same version as the PHP version they are bundled with; no wildcards
				// no need to match anything in this case (and we couldn't, anyway, since only a "x.y.0" version would match an "x.y" series entry)
				// instead, we grab the series straight from the version number
				$matchingSeries = [ implode('.', array_slice(explode('.', $package['version']), 0, 2)) ]; // 7.3, 7.4, 8.0 etc
			} else {
				$matchingSeries = $findseries($package);
			}
			foreach($matchingSeries as $serie) {
				$insertExtension->reset();
				$insertExtension->bindValue(':name', str_replace("heroku-sys/", "", $package['name']), SQLITE3_TEXT);
				if($isBundled) {
					$insertExtension->bindValue(':url', $getBuiltinExtensionUrl($package['name']), SQLITE3_TEXT);
				} else {
					$insertExtension->bindValue(':url', $package['homepage'] ?? null, SQLITE3_TEXT);
				}
				$insertExtension->bindValue(':version', $package['version'], SQLITE3_TEXT);
				$insertExtension->bindValue(':runtime', 'php', SQLITE3_TEXT);
				$insertExtension->bindValue(':series', $serie, SQLITE3_TEXT);
				$insertExtension->bindValue(':stack', $stack, SQLITE3_TEXT);
				$insertExtension->bindValue(':bundled', $isBundled, SQLITE3_INTEGER);
				$insertExtension->bindValue(':enabled', 0, SQLITE3_INTEGER); // not enabled by default
				$insertExtension->execute();
			}
		}
		continue;
	}
	// for all other packages, we also want the ability for packages to target multiple stacks, so we match our known ones against the require entry and loop
	foreach($findstacks($package) as $stack) {
		$insertPackage->reset();
		$insertPackage->bindValue(':name', str_replace("heroku-sys/", "", $package['name']), SQLITE3_TEXT);
		$insertPackage->bindValue(':url', $package['homepage'] ?? null, SQLITE3_TEXT);
		$insertPackage->bindValue(':version', $package['version'], SQLITE3_TEXT);
		$insertPackage->bindValue(':type', $package['type'], SQLITE3_TEXT);
		$insertPackage->bindValue(':stack', $stack, SQLITE3_TEXT);
		if($package['type'] == 'heroku-sys-php') {
			// PHP bundles extensions that are shared objects (with their own package metadata, handled further above), and extensions that are compiled in (handled here)
			$serie = implode('.', array_slice(explode('.', $package['version']), 0, 2)); // 7.3, 7.4, 8.0 etc
			// 'replace' contains entries for all compiled-in extensions, so we make an entry for each of them, copying over the PHP package's version number
			foreach($package['replace']??[] as $rname => $rversion) {
				if(strpos($rname, "heroku-sys/ext-") !== 0 || strpos($rname, ".native")) continue;
				$insertExtension->reset();
				$insertExtension->bindValue(':name', str_replace("heroku-sys/", "", $rname), SQLITE3_TEXT);
				$insertExtension->bindValue(':url', $getBuiltinExtensionUrl($rname), SQLITE3_TEXT);
				$insertExtension->bindValue(':version', $package['version'], SQLITE3_TEXT);
				$insertExtension->bindValue(':runtime', 'php', SQLITE3_TEXT);
				$insertExtension->bindValue(':series', $serie, SQLITE3_TEXT);
				$insertExtension->bindValue(':stack', $stack, SQLITE3_TEXT);
				$insertExtension->bindValue(':bundled', 1, SQLITE3_INTEGER);
				$insertExtension->bindValue(':enabled', 1, SQLITE3_INTEGER); // enabled by default, because compiled in
				$insertExtension->execute();
			}
		} elseif($package['type'] == 'heroku-sys-program' && $package['name'] == 'heroku-sys/composer') {
			$serie = explode('.', $package['version']);
			if($serie[0] == '2' && $serie[1] == '2') {
				$serie = '2 LTS'; // Composer 2.2 is LTS
			} else {
				$serie = $serie[0]; // 3, 4, 5 etc - semver major version
			}
		} else {
			$serie = explode('.', $package['version'])[0]; // 3, 4, 5 etc - semver major version
		}
		$insertPackage->bindValue(':series', $serie, SQLITE3_TEXT);
		$insertPackage->execute();
	}
}

$latestRuntimesByStack = []; // remember these for the next step, where we fetch all default extensions for them
$runtimeSeriesByStack = [];
$runtimesQuery = ["SELECT name, series"];
foreach($stacks as $key => $stack) {
	$runtimesQuery[] = ", MAX(CASE WHEN stack = '$stack' THEN version END COLLATE VERSION_CMP) AS '$stack'";
}
$runtimesQuery[] = "FROM packages WHERE name = 'php' GROUP BY name, series ORDER BY series COLLATE VERSION_CMP ASC";
$results = $db->query(implode(" ", $runtimesQuery));
$runtimes = [];
while($row = $results->fetchArray(SQLITE3_ASSOC)) {
	$row["name"] = strtoupper($row["name"]); // "PHP"
	$runtimes[] = $row;
	foreach($stacks as $stack) {
		if($row[$stack]) {
			$latestRuntimesByStack[$stack][$row["series"]] = $row[$stack];
			$runtimeSeriesByStack[$stack][] = $row["series"];
		}
	}
}

// check which runtime series were actually found in the repo
$detectedSeries = array_unique(array_merge(...$runtimeSeriesByStack));
// if they're not whitelisted, we do not want to print them
if($ignoredSeries = array_diff($detectedSeries, $series)) {
	// a warning is appropriate here: there are available packages that are not whitelisted and thus will not show up in documentation
	fprintf(STDERR, "WARNING: runtime series ignored in input due to missing whitelist entries: %s\n", implode(', ', $ignoredSeries));
	if($strict) {
		fputs(STDERR, "ERROR: now aborting due to strict mode\n");
		exit(1);
	}
}
// if they're whitelisted, but missing... well...
if($missingSeries = array_diff($series, $detectedSeries)) {
	// this is only a notice: version series are "whitelisted", not "expected", and the generated info will match reality
	fprintf(STDERR, "NOTICE: whitelisted runtime series not found in input: %s\n", implode(', ', $missingSeries));
}
// finally, show just the real series that are even available as runtimes; no need to show empty columns
$series = array_intersect($series, $detectedSeries);
// and from these also get the stacks that are actually populated
$stacks = array_keys(array_filter($runtimeSeriesByStack)); // filter with no args removes empty items
$stacks = array_combine(range(1, count($stacks)), array_values($stacks)); // reindex from key 1, for our footnotes

// clean up the list of runtimes by removing series not on whitelist
$runtimes = array_filter($runtimes, function($runtime) use($series) { return in_array($runtime['series'], $series); });

$extensionsQuery = ["SELECT extensions.name, extensions.url"];
foreach($series as $serie) {
	foreach($stacks as $stack) {
		$extensionsQuery[] = ", MAX(CASE WHEN extensions.series = '$serie' AND extensions.stack='$stack' THEN extensions.enabled END) AS 'enabled_{$serie}_{$stack}'";
	}
}
$extensionsQuery[] = "FROM extensions";
$extensionsQuery[] = "WHERE extensions.bundled = 1 AND(0";
foreach($latestRuntimesByStack as $stack => $versions) {
	foreach($versions as $serie => $version) {
		// we intentionally don't use prepared statements here
		// some bug with positional parameter binding...
		$extensionsQuery[] = "OR (extensions.stack = '$stack' AND extensions.version = '$version')";
	}
}
$extensionsQuery[] = ") GROUP BY extensions.name ORDER BY extensions.name ASC";
$result = $db->query(implode(" ", $extensionsQuery));
$bExtensions = [];
while($row = $result->fetchArray(SQLITE3_ASSOC)) {
	$row['data'] = [];
	foreach($series as $serie) {
		$row['data'][$serie] = $filterStackVersions($row, $serie, $stacks, $runtimeSeriesByStack, function($row, $serie, $stack) { return isset($row["enabled_{$serie}_{$stack}"]) ? strtr($row["enabled_{$serie}_{$stack}"], ["0" => "&#x2731;", "1" => "&#x2714;"]) : null; });
	}
	$bExtensions[] = $row;
}

$extensionsQuery = ["SELECT extensions.name, extensions.url, substr(extensions.version, 1, instr(extensions.version, '.')) AS major_version"];
foreach($series as $serie) {
	foreach($stacks as $stack) {
		$extensionsQuery[] = ", MAX(CASE WHEN extensions.series = '$serie' AND extensions.stack = '$stack' THEN extensions.version END COLLATE VERSION_CMP) AS 'version_{$serie}_{$stack}'";
	}
}
$extensionsQuery[] = "FROM extensions WHERE extensions.bundled = 0 GROUP BY extensions.name, major_version ORDER BY extensions.name ASC, major_version COLLATE VERSION_CMP ASC";
$result = $db->query(implode(" ", $extensionsQuery));
$eExtensions = [];
while($row = $result->fetchArray(SQLITE3_ASSOC)) {
	$row['data'] = [];
	foreach($series as $serie) {
		$row['data'][$serie] = $filterStackVersions($row, $serie, $stacks, $runtimeSeriesByStack, function($row, $serie, $stack) { return $row["version_{$serie}_{$stack}"] ?? null; });
	}
	$eExtensions[] = $row;
}
// find those extensions that have multiple major versions
$extCounts = array_count_values(array_column($eExtensions, 'name')); // preserves keys
// remove major_version key from each non-matched row
foreach($eExtensions as &$row) if($extCounts[$row['name']] < 2) unset($row['major_version']);
// but then see if any of these have no overlap by series, e.g. v1 only for PHP 5.5 and 5.6, and v2 for 7.0+; we can collapse them into one row then after all
foreach($extCounts as $name => $count) {
	if($count < 2) continue;
	// this preserves keys from $eExtensions, so we can splice later
	$collapse = array_filter($eExtensions, function($row) use($name) { return $row["name"] == $name; });
	foreach($collapse as &$row) { $row = array_filter($row); }
	// now figure out the overlap by intersecting an entry's keys with the next entry's keys
	// if only "name", "data" and "major_version" remain, then none of the other keys intersected, meaning no overlap
	// this doesn't work: count(array_intersect_key(...$collapse)) == 3
	// because for more than two arguments, it returns keys present in the first array that are in ALL other arrays, not ANY
	// meaning if the first and second have overlap, but the first and third do not, it returns the wrong stuff
	$overlap = false;
	while($current = current($collapse)) {
		$next = next($collapse);
		if(!$next) break;
		if(count(array_intersect_key($current, $next)) != 3) {
			// contains more than just "name", "data", and "major_version" keys
			// that means at least one of the runtime series "columm" contains more than one major version
			// we thus cannot collapse anything, even if some versions do not have any overlap, to avoid confusion
			// (e.g. ext-phalcon 2.x is only on 5.5 and 5.6, 3.x is on 7.0+, 4.x is on 7.3+, so we want three rows, even though 2.x and 3.x have no overlap)
			$overlap = true;
			break;
		}
	}
	if(!$overlap) {
		// no overlap between any major versions per runtime series
		// we can collapse the multiple major versions into one row
		$position = array_key_first($collapse);
		$length = count($collapse);
		$collapse = array_merge(...$collapse); // result is one row, and we unpack it
		// recalculate data array
		foreach($series as $serie) {
			$collapse['data'][$serie] = $filterStackVersions($collapse, $serie, $stacks, $runtimeSeriesByStack, function($row, $serie, $stack) { return $row["version_{$serie}_{$stack}"] ?? null; });
		}
		unset($collapse['major_version']);
		// overwrite collapsible rows with our new single one
		array_splice($eExtensions, $position, $length, [$collapse]);
	}
}
unset($row); // unlink &$row reference from above, we're re-using that variable below

$composersQuery = ["SELECT name, series"];
foreach($stacks as $key => $stack) {
	$composersQuery[] = ", MAX(CASE WHEN stack = '$stack' THEN version END COLLATE VERSION_CMP) AS '$stack'";
}
$composersQuery[] = "FROM packages WHERE name = 'composer' GROUP BY name, series ORDER BY series COLLATE VERSION_CMP ASC";
$results = $db->query(implode(" ", $composersQuery));
$composers = [];
while($row = $results->fetchArray(SQLITE3_ASSOC)) {
	$row["name"] = ucfirst($row["name"]); // "Composer"
	$row["series"] = $row["series"].(strpos($row["series"], "LTS")?"":".x"); // "2.x"
	$composers[] = $row;
}

$webserversQuery = ["SELECT name, series"];
foreach($stacks as $key => $stack) {
	$webserversQuery[] = ", MAX(CASE WHEN stack = '$stack' THEN version END COLLATE VERSION_CMP) AS '$stack'";
}
$webserversQuery[] = "FROM packages WHERE type = 'heroku-sys-webserver' GROUP BY name, series ORDER BY name ASC, series COLLATE VERSION_CMP ASC";
$results = $db->query(implode(" ", $webserversQuery));
$webservers = [];
while($row = $results->fetchArray(SQLITE3_ASSOC)) {
	$row["name"] = ucfirst($row["name"]); // "Nginx"
	$row["series"] = $row["series"].".x"; // "1.x"
	$webservers[] = $row;
}

$twig = new Twig\Environment(new \Twig\Loader\FilesystemLoader(__DIR__));

$templates = [
	"runtimes" =>  [
		'stacks' => $stacks,
		'eol' => $eol,
		'packages' => $runtimes,
	],
	"built-in-extensions" => [
		'series' => $series,
		'stacks' => $stacks,
		'eol' => $eol,
		'extensions' => $bExtensions,
	],
	"third-party-extensions" => [
		'series' => $series,
		'stacks' => $stacks,
		'eol' => $eol,
		'extensions' => $eExtensions,
	],
	"composers" =>  [
		'stacks' => $stacks,
		'packages' => $composers,
	],
	"webservers" =>  [
		'stacks' => $stacks,
		'packages' => $webservers,
	],
];

foreach(($sections?: ["runtimes" => true, "built-in-extensions" => true, "third-party-extensions" => true, "composers" => true, "webservers" => true]) as $section => $ignore) {
	echo $twig->render("$section.twig", $templates[$section]);
}
