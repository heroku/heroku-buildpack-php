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
		default:
			if(!is_numeric($suffix)) {
				fprintf(STDERR, "WARNING: ignoring invalid suffix '%s' in 'memory_limit' value '%s'\n", $suffix, $amount);
			}
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

$opts = getopt("b:ht:v", array("help", "verbose"), $rest_index);
$argv = array_slice($argv, $rest_index);
$argc = count($argv);
$print_help = isset($opts['h']) || isset($opts['help']);
if(isset($opts['verbose'])) {
	$verbose = 2;
} else {
	$verbose = count((array)($opts['v']??null)); // -v can be repeated to increase the level
}
if($argc != 2 || $print_help) {
	fprintf($print_help ? STDOUT : STDERR,
		"Usage:\n".
		"  %s [options] <RAM_AVAIL> <NUM_CORES>\n\n",
		basename(__FILE__)
	);
	fputs($print_help ? STDOUT : STDERR,
		"Determines the number of PHP-FPM worker processes for given RAM and CPU cores.\n\n".
		"The result will always be limited to at most (RAM_AVAIL / memory_limit) workers.\n\n".
		"A second limit, factoring in the number of CPU cores, is calculated as follows:\n".
		"ceil(log_2(RAM_AVAIL / CALC_BASE)) * NUM_CORES * 2 * (CALC_BASE / memory_limit)\n\n".
		"The purpose of applying both of these limits is to ensure that:\n".
		"1) the number of workers does not grow too rapidly as available RAM increases;\n".
		"2) the number of workers per CPU core remains reasonable;\n".
		"3) the number of workers never exceeds available RAM for given memory_limit;\n".
		"4) adjusting PHP memory_limit has a linear influence on the number of workers.\n\n".
		"Options:\n".
		"  -b <CALC_BASE>     The PHP memory_limit on which the calculation of the\n".
		"                     scaling factors should be based. Defaults to '128M'.\n".
		"  -h, --help         Display this help screen and exit.\n".
		"  -t <DOCUMENT_ROOT> Dir to read '.user.ini' with memory_limit settings from.\n".
		"  -v                 Be a little more verbose when printing information.\n".
		"  -vv, --verbose     Be more verbose when printing information.\n\n".
		"Lines containing php_value or php_admin_value memory_limit INI directives from\n".
		"a PHP-FPM configuration file or `php-fpm -tt' dump can be fed via STDIN. These\n".
		"will then be taken into account when determining the effective memory_limit.\n\n"
	);
	exit($print_help ? 0 : 2);
}

$ram = stringtobytes($argv[0]); // first arg is the available memory
fprintf(STDERR, "Available RAM is %s Bytes\n", bytestostring($ram));

$cores = $argv[1];
if($verbose) {
	fprintf(STDERR, "Number of CPU cores is %d\n", (int)$cores);
}

$calc_base = $opts['b'] ?? "128M";
if($verbose >= 2) {
	fprintf(STDERR, "Determining scaling factor based on a memory_limit of %s\n", $calc_base);
}
$calc_base = stringtobytes($calc_base);
$factor = ceil(log($ram/$calc_base, 2));
if($verbose >= 2) {
	fprintf(STDERR, "Scaling factor is %d\n", $factor);
}

// parse potential php_value and php_admin_value data from STDIN
// the expected format is lines like the following:
// php_value[memory_limit] = 128M
// php_admin_value[memory_limit] = 128M
$limits = (stream_isatty(STDIN) ? [] : parse_ini_string(stream_get_contents(STDIN)));
if($limits === false) {
	fputs(STDERR, "ERROR: Malformed FPM php_value/php_admin_value directives on STDIN.\n");
	exit(1);
}

if($verbose >= 2) {
	if(isset($limits['php_value'])) {
		fputs(STDERR, "memory_limit changed by php_value in PHP-FPM configuration\n");
	}
}

if(
	isset($opts['t']) &&
	is_readable($userini_path = $opts['t'].'/.user.ini')
) {
	// we only read the topmost .user.ini inside document root
	$userini = parse_ini_file($userini_path);
	if($userini === false) {
		fprintf(STDERR, "ERROR: Malformed %s.\n", $userini_path);
		exit(1);
	}
	if(isset($userini['memory_limit'])) {
		if($verbose >= 2) {
			fprintf(STDERR, "memory_limit changed by %s\n", $userini_path);
		}
		// if .user.ini has a limit set, it will overwrite an FPM config php_value, but not a php_admin_value
		$limits['php_value']['memory_limit'] = $userini['memory_limit'];
	}
}

$ini_set_result = null;
if(isset($limits['php_admin_value']['memory_limit'])) {
	// these take precedence and cannot be overridden later
	if($verbose >= 2) {
		fputs(STDERR, "memory_limit overridden by php_admin_value in PHP-FPM configuration\n");
	}
	$ini_set_result = ini_set('memory_limit', $limits['php_admin_value']['memory_limit']);
} elseif(isset($limits['php_value']['memory_limit'])) {
	$ini_set_result = ini_set('memory_limit', $limits['php_value']['memory_limit']);
}

if($ini_set_result === false) {
	fputs(STDERR, "ERROR: Illegal value for memory_limit configuration directive.\n");
	exit(1);
}

$limit_str = ini_get('memory_limit');
$limit = stringtobytes($limit_str);

if($limit < 1) { // yes, including 0, to hedge against division by zero (although ini_set("memory_limit", 0) should never succeed)
	$limit = $ram;
	fputs(STDERR, "PHP memory_limit is unlimited\n");
} else {
	fprintf(STDERR, "PHP memory_limit is %s Bytes\n", $limit_str); // we output the original value here, since it's user supplied
}

$result = floor($factor * $cores * 2 * $calc_base / $limit);

$max_workers_for_ram = floor($ram/$limit);

if($verbose) {
	fprintf(STDERR, "Calculated number of workers based on RAM and CPU cores is %d\n", $result);
}

$print_limit_notice = false;
if($max_workers_for_ram < $result) {
	$result = $max_workers_for_ram;
	if($verbose) {
		$print_limit_notice = true;
	}
} elseif($max_workers_for_ram > $result) {
	$print_limit_notice = true;
}

if($print_limit_notice) {
	fprintf(STDERR, "Maximum number of workers that fit available RAM at memory_limit is %d\n", $max_workers_for_ram);
	fprintf(STDERR, "Limiting number of workers to %d\n", $result);
}

printf("%d", $result);
