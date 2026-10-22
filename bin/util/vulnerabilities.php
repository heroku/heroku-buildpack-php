<?php

$fixed = array(
	// minimum patch version, and the severe vulnerabilities fixed by it
	// builds fail for older patch versions, which apps only get when they require an exact version
	// PHP versions older than 8.1 aren't listed since they can't be used any more: they were only available on heroku-20 and older, which are no longer supported
	"8.1" => array("8.1.34", "CVE-2026-109618 and CVE-2026-109619"), // via the patched 8.1.34+heroku1, the only 8.1.34 build in the repository
	"8.2" => array("8.2.35", "CVE-2026-109618 and CVE-2026-109619"),
	"8.3" => array("8.3.36", "CVE-2026-109618 and CVE-2026-109619"),
	"8.4" => array("8.4.27", "CVE-2026-109618 and CVE-2026-109619"),
	"8.5" => array("8.5.12", "CVE-2026-109618 and CVE-2026-109619"),
);

if(!isset($fixed[PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION])) exit(0);

list($minimum, $vulnerabilities) = $fixed[PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION];

if(version_compare(PHP_VERSION, $minimum, "<")) {
	echo("$minimum $vulnerabilities");
	exit(1);
}
