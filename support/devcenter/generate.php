#!/usr/bin/env php
<?php

use Composer\Semver\Comparator;

require('vendor/autoload.php');

// these need updating from time to time to add new stacks and remove EOL ones
$stacks = [
	1 => '18', // the offset we start with here is relevant for the numbering of footnotes
	'20',
];
// these need updating from time to time to add new series and remove EOL ones
$series = [
	'7.1',
	'7.2',
	'7.3',
	'7.4',
	'8.0',
	'8.1',
];

$findstacks = function(array $package) use($stacks) {
	if($package['require']) {
		if(isset($package['require']['heroku-sys/heroku'])) {
			return Composer\Semver\Semver::satisfiedBy($stacks, $package['require']['heroku-sys/heroku']);
		}
	}
	return [];
};

$findseries = function(array $package) use($series) {
	if($package['require']) {
		if(isset($package['require']['heroku-sys/php'])) {
			return Composer\Semver\Semver::satisfiedBy($series, $package['require']['heroku-sys/php']);
		}
	}
	return [];
};

$stackname = function($version) {
	return "heroku-${version}";
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

$sections = getopt('', ['runtimes', 'built-in-extensions', 'third-party-extensions', 'composers', 'webservers'], $restIndex);
$posArgs = array_slice($argv, $restIndex);

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
$eol = array_filter(array_map(function($eolDates) {
	if(strtotime($eolDates[1]) < time())
		return "eol";
	elseif(strtotime($eolDates[0]) < time())
		return "security";
	else
		return null; // will be removed by array_filter
}, include(__DIR__ . "/../../bin/util/eol.php")));

$packages = [];
foreach($repositories as $repository) {
	$packages = array_merge($packages, $repository['packages'][0]);
}

$db = new SQLite3(':memory:');
$db->createCollation('VERSION_CMP', 'version_compare'); // for sorting/MAXing versions; we have to use it explicitly inside MAX(CASE…) statements in addition to setting it on the version column
$db->exec("CREATE TABLE packages (name TEXT COLLATE NOCASE, version TEXT COLLATE VERSION_CMP, type TEXT, series TEXT, stack TEXT)");
$db->exec("CREATE TABLE extensions (name TEXT COLLATE NOCASE, url TEXT, version TEXT COLLATE VERSION_CMP, runtime TEXT, series TEXT, stack TEXT, bundled INTEGER DEFAULT 0, enabled INTEGER DEFAULT 1)");
$insertPackage = $db->prepare("INSERT INTO packages (name, version, type, series, stack) VALUES(:name, :version, :type, :series, :stack)");
$insertExtension = $db->prepare("INSERT INTO extensions (name, url, version, runtime, series, stack, bundled, enabled) VALUES(:name, :url, :version, :runtime, :series, :stack, :bundled, :enabled)");

foreach($packages as $package) {
	if($package['type'] == 'heroku-sys-php-extension') {
		foreach($findstacks($package) as $stack) {
			foreach($findseries($package) as $serie) {
				$insertExtension->reset();
				$insertExtension->bindValue(':name', str_replace("heroku-sys/", "", $package['name']), SQLITE3_TEXT);
				$insertExtension->bindValue(':url', $package['homepage'] ?? null, SQLITE3_TEXT);
				$insertExtension->bindValue(':version', $package['version'], SQLITE3_TEXT);
				$insertExtension->bindValue(':runtime', 'php', SQLITE3_TEXT);
				$insertExtension->bindValue(':series', $serie, SQLITE3_TEXT);
				$insertExtension->bindValue(':stack', $stack, SQLITE3_TEXT);
				$insertExtension->bindValue(':bundled', 0, SQLITE3_INTEGER);
				$insertExtension->bindValue(':enabled', 0, SQLITE3_INTEGER);
				$insertExtension->execute();
			}
		}
		continue;
	}
	foreach($findstacks($package) as $stack) {
		$insertPackage->reset();
		$insertPackage->bindValue(':name', str_replace("heroku-sys/", "", $package['name']), SQLITE3_TEXT);
		$insertPackage->bindValue(':url', $package['homepage'] ?? null, SQLITE3_TEXT);
		$insertPackage->bindValue(':version', $package['version'], SQLITE3_TEXT);
		$insertPackage->bindValue(':type', $package['type'], SQLITE3_TEXT);
		$insertPackage->bindValue(':stack', $stack, SQLITE3_TEXT);
		if($package['type'] == 'heroku-sys-php') {
			$serie = implode('.', array_slice(explode('.', $package['version']), 0, 2)); // 7.3, 7.4, 8.0 etc
			foreach($package["replace"] as $rname => $rversion) {
				if(strpos($rname, "heroku-sys/ext-") !== 0) continue;
				$insertExtension->reset();
				$insertExtension->bindValue(':name', str_replace("heroku-sys/", "", $rname), SQLITE3_TEXT);
				$insertExtension->bindValue(':url', $getBuiltinExtensionUrl($rname), SQLITE3_TEXT);
				$insertExtension->bindValue(':version', $package['version'], SQLITE3_TEXT);
				$insertExtension->bindValue(':runtime', 'php', SQLITE3_TEXT);
				$insertExtension->bindValue(':series', $serie, SQLITE3_TEXT);
				$insertExtension->bindValue(':stack', $stack, SQLITE3_TEXT);
				$insertExtension->bindValue(':bundled', 1, SQLITE3_INTEGER);
				$insertExtension->bindValue(':enabled', !isset($package["extra"]["shared"][$rname]), SQLITE3_INTEGER);
				$insertExtension->execute();
			}
		} elseif($package['type'] == 'heroku-sys-program' && $package['name'] == 'heroku-sys/composer') {
			$serie = explode('.', $package['version']);
			if($serie[0] == '2' && $serie[1] == '2') {
				$serie = 'LTS 2.2'; // Composer 2.2 is LTS
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
	$runtimesQuery[] = ", MAX(CASE WHEN stack = '${stack}' THEN version END COLLATE VERSION_CMP) AS '${stack}'";
}
$runtimesQuery[] = "FROM packages WHERE name = 'php' GROUP BY name, series ORDER BY series ASC";
$results = $db->query(implode(" ", $runtimesQuery));
$runtimes = [];
while($row = $results->fetchArray(SQLITE3_ASSOC)) {
	$row["name"] = strtoupper($row["name"]); // "PHP"
	$runtimes[] = $row;
	foreach($stacks as $stack) {
		if($row["${stack}"]) {
			$latestRuntimesByStack[$stack][$row["series"]] = $row["${stack}"];
			$runtimeSeriesByStack[$stack][] = $row["series"];
		}
	}
}

// now show just the real series that are even available as runtimes; no need to show empty columns
$series = array_unique(array_merge(...$runtimeSeriesByStack));
// and from these also get the stacks that are actually populated
$stacks = array_keys(array_filter($runtimeSeriesByStack)); // filter with no args removes empty items
$stacks = array_combine(range(1, count($stacks)), array_values($stacks)); // reindex from key 1, for our footnotes

$extensionsQuery = ["SELECT extensions.name, extensions.url"];
foreach($series as $serie) {
	foreach($stacks as $stack) {
		$extensionsQuery[] = ", MAX(CASE WHEN extensions.series = '${serie}' AND extensions.stack='${stack}' THEN extensions.enabled END) AS 'enabled_${serie}_${stack}'";
	}
}
$extensionsQuery[] = "FROM extensions";
$extensionsQuery[] = "WHERE extensions.bundled = 1 AND(0";
foreach($latestRuntimesByStack as $stack => $versions) {
	foreach($versions as $serie => $version) {
		// we intentionally don't use prepared statements here
		// some bug with positional parameter binding...
		$extensionsQuery[] = "OR (extensions.stack = '${stack}' AND extensions.version = '${version}')";
	}
}
$extensionsQuery[] = ") GROUP BY extensions.name ORDER BY extensions.name ASC";
$result = $db->query(implode(" ", $extensionsQuery));
$bExtensions = [];
while($row = $result->fetchArray(SQLITE3_ASSOC)) {
	$row['data'] = [];
	foreach($series as $serie) {
		$row['data'][$serie] = $filterStackVersions($row, $serie, $stacks, $runtimeSeriesByStack, function($row, $serie, $stack) { return isset($row["enabled_${serie}_${stack}"]) ? strtr($row["enabled_${serie}_${stack}"], ["0" => "&#x2731;", "1" => "&#x2714;"]) : null; });
	}
	$bExtensions[] = $row;
}

$extensionsQuery = ["SELECT extensions.name, extensions.url, substr(extensions.version, 1, instr(extensions.version, '.')) AS major_version"];
foreach($series as $serie) {
	foreach($stacks as $stack) {
		$extensionsQuery[] = ", MAX(CASE WHEN extensions.series = '${serie}' AND extensions.stack = '${stack}' THEN extensions.version END COLLATE VERSION_CMP) AS 'version_${serie}_${stack}'";
	}
}
$extensionsQuery[] = "FROM extensions WHERE extensions.bundled = 0 GROUP BY extensions.name, major_version ORDER BY extensions.name ASC, major_version ASC";
$result = $db->query(implode(" ", $extensionsQuery));
$eExtensions = [];
while($row = $result->fetchArray(SQLITE3_ASSOC)) {
	$row['data'] = [];
	foreach($series as $serie) {
		$row['data'][$serie] = $filterStackVersions($row, $serie, $stacks, $runtimeSeriesByStack, function($row, $serie, $stack) { return $row["version_${serie}_${stack}"] ?? null; });
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
			$collapse['data'][$serie] = $filterStackVersions($collapse, $serie, $stacks, $runtimeSeriesByStack, function($row, $serie, $stack) { return $row["version_${serie}_${stack}"] ?? null; });
		}
		unset($collapse['major_version']);
		// overwrite collapsible rows with our new single one
		array_splice($eExtensions, $position, $length, [$collapse]);
	}
}

$composersQuery = ["SELECT name, series"];
foreach($stacks as $key => $stack) {
	$composersQuery[] = ", MAX(CASE WHEN stack = '${stack}' THEN version END COLLATE VERSION_CMP) AS '${stack}'";
}
$composersQuery[] = "FROM packages WHERE name = 'composer' GROUP BY name, series ORDER BY series ASC";
$results = $db->query(implode(" ", $composersQuery));
$composers = [];
while($row = $results->fetchArray(SQLITE3_ASSOC)) {
	$row["name"] = ucfirst($row["name"]); // "Composer"
	$row["series"] = $row["series"].".x"; // "2.x"
	$composers[] = $row;
}

$webserversQuery = ["SELECT name, series"];
foreach($stacks as $key => $stack) {
	$webserversQuery[] = ", MAX(CASE WHEN stack = '${stack}' THEN version END COLLATE VERSION_CMP) AS '${stack}'";
}
$webserversQuery[] = "FROM packages WHERE type = 'heroku-sys-webserver' GROUP BY name, series ORDER BY name ASC, series ASC";
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
