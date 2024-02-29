#!/usr/bin/env php
<?php

require('vendor/autoload.php');

$sync = file_get_contents("php://stdin");

// first, split the output from sync.sh by its section headers
// we want the "kind" of operation to be captured as well, since we only care about additions
$sections = "(IGNORED|ADDED|UPDATED|REMOVED)";
$splits = preg_split("/^The following packages will be $sections/m", $sync, 0, PREG_SPLIT_DELIM_CAPTURE);

$package_pattern = "/^\s*-\s+(?P<name>(?P<ext>ext-)?[^-]+)-(?P<version>\d+(\.\d+)+)(?(2)_php-(?P<series>\d+\.\d))\s*$/m";

// the result from the splitting is a list of section outputs and captured delimiters
// think, roughly: ["maybe some prologue text", "IGNORED", "- (none)", "ADDED", "Blah Blah\n- php-8.9.10", "UPDATED", "- (none)", "REMOVED", "- (none)"]
// we now iterate over these, remember the section header we see, and get info out of all "ADDED" blocks we encounter (might be several!)
$additions = [];
$section = null;

foreach($splits as $split) {
	if(preg_match("/^$sections$/", $split, $section_match)) {
		$section = $section_match[1];
		continue;
	}
	if($section == "ADDED") {
		preg_match_all($package_pattern, $split, $packages, PREG_SET_ORDER);
		foreach($packages as $package) {
			$additions[] = [
				"name" => $package["name"],
				"version" => $package["version"],
				"is_ext" => (bool)$package["ext"],
				"series" => match($package["name"]) {
					"php" => preg_filter("/^(\d+)\..+/", '$1', $package["version"]),
					"nginx" => preg_filter("/^(\d+\.\d+)\..+$/", '$1', $package["version"]),
					default => $package["series"] ?? null,
				},
			];
		}
	}
}

// naive deduplication, we don't care about PHP version ranges for extensions for now
$additions = array_combine(array_map(fn($package) => $package["name"]."-".$package["version"], $additions), $additions);

$latest_version = fn($carry, $package) => version_compare($carry["version"] ?? 0, $package["version"], ">") ? $carry : $package;

$data = [
	"phps" => array_filter($additions, fn($package) => $package["name"] == "php"),
	"extensions" => array_filter($additions, fn($package) => $package["is_ext"]),
	"composers" => array_filter($additions, fn($package) => $package["name"] == "composer"),
	"apache" => array_reduce(
		array_filter($additions, fn($package) => $package["name"] == "apache"),
		$latest_version
	),
	"nginx" => array_reduce(
		array_filter($additions, fn($package) => $package["name"] == "nginx"),
		$latest_version
	),
	"libraries" => array_filter($additions, fn($package) => strpos($package["name"], "lib") === 0),
	"blackfire" => array_reduce( //
		array_filter($additions, fn($package) => $package["name"] == "blackfire"),
		$latest_version
	),
];

$twig = new Twig\Environment(new \Twig\Loader\FilesystemLoader(__DIR__));
echo $twig->render("changelog.twig", $data);
