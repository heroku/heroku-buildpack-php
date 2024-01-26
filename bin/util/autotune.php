#!/usr/bin/env php
<?php

function stringtobytes($amount) {
	// convert "256M" etc to bytes
	switch($suffix = strtolower(substr($amount, -1))) {
		case 'g':
			$amount = (int)$amount * 1024;
		case 'm':
			$amount = (int)$amount * 1024;
		case 'k':
			$amount = (int)$amount * 1024;
			break;
		case !is_numeric($suffix):
			fprintf(STDERR, "WARNING: ignoring invalid suffix '%s' in 'memory_limit' value '%s'\n", $suffix, $amount);
		default:
			$amount = (int)$amount;
	}
	return $amount;
}

function bytestostring($amount) {
	$suffixes = array('K', 'M', 'G', 'T', 'P', 'E');
	$suffix = '';
	while($suffixes && $amount % 1024 == 0) {
		$amount /= 1024;
		$suffix = array_shift($suffixes);
	}
	return sprintf("%d%s", $amount, $suffix);
}

$opts = getopt("t:", array(), $rest_index);
$argv = array_slice($argv, $rest_index);
$argc = count($argv);
if($argc < 1 || $argc > 2) {
	fprintf(STDERR,
		"Usage:\n".
		"  %s [options] <RAM_AVAILABLE> [<RAM_LIMIT>]\n\n",
		basename(__FILE__)
	);
	fputs(STDERR,
		"Options:\n".
		"  -t <DOCUMENT_ROOT> Dir to read '.user.ini' with 'memory_limit' settings from\n\n".
		"php_value or php_admin_value lines from a PHP-FPM config can be fed via STDIN.\n\n"
	);
	exit(2);
}

// first, parse potential php_value and php_admin_value data from STDIN
// the expected format is lines like the following:
// php_value[memory_limit] = 128M
// php_admin_value[memory_limit] = 128M
$limits = (stream_isatty(STDIN) ? [] : parse_ini_string(stream_get_contents(STDIN)));
if($limits === false) {
	fputs(STDERR, "ERROR: Malformed FPM php_value/php_admin_value directives on STDIN.\n");
	exit(1);
}

if(
	isset($opts['t']) &&
	is_readable($opts['t'].'/.user.ini')
) {
	// we only read the topmost .user.ini inside document root
	$userini = parse_ini_file($opts['t'].'/.user.ini');
	if($userini === false) {
		fputs(STDERR, "ERROR: Malformed .user.ini in document root.\n");
		exit(1);
	}
	if(isset($userini['memory_limit'])) {
		// if .user.ini has a limit set, it will overwrite an FPM config php_value, but not a php_admin_value
		$limits['php_value']['memory_limit'] = $userini['memory_limit'];
	}
}

if(isset($limits['php_admin_value']['memory_limit'])) {
	ini_set('memory_limit', $limits['php_admin_value']['memory_limit']);
} elseif(isset($limits['php_value']['memory_limit'])) {
	ini_set('memory_limit', $limits['php_value']['memory_limit']);
}

$ram = stringtobytes($argv[0]); // first arg is the available memory

fprintf(STDERR, "Available RAM is %s Bytes\n", bytestostring($ram));

if(isset($argv[1])) { // optional second arg is the maximum RAM we're allowed
	$max_ram_string = $argv[1];
	$max_ram = stringtobytes($max_ram_string);

	if($ram > $max_ram) {
		$ram = $max_ram;
		fprintf(STDERR, "Limiting RAM usage to %s Bytes\n", bytestostring($ram));
	}
}

$limit = ini_get('memory_limit');
fprintf(STDERR, "PHP memory_limit is %s Bytes\n", $limit); // we output the original value here, since it's user supplied

echo floor($ram / (stringtobytes($limit)?:-1));
