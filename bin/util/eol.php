<?php

$eol = array(
	// security fixes EOL and full EOL dates
	"5.5" => array("2015-07-21", "2016-07-21"),
	"5.6" => array("2017-01-19", "2018-12-31"),
	"7.0" => array("2017-12-03", "2018-12-03"),
	"7.1" => array("2018-12-01", "2019-12-01"),
	"7.2" => array("2019-11-30", "2020-11-30"),
	"7.3" => array("2020-12-06", "2021-12-06"),
	"7.4" => array("2021-11-28", "2022-11-28"),
	"8.0" => array("2022-11-26", "2023-11-26"),
);

if(!isset($eol[PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION])) exit(0);

list($secdate, $eoldate) = $eol[PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION];

if(strtotime($eoldate) < time()) {
	echo($eoldate);
	exit(2); // fully EOL
} elseif(strtotime($eoldate) < strtotime("+3 months")) {
	echo($eoldate);
	exit(3); // less than three months to full EOL
} elseif(strtotime($secdate) < time()) {
	echo($eoldate); // we want to print the looming full EOL date here
	exit(4); // security fixes only support
} elseif(strtotime($secdate) < strtotime("+3 months")) {
	echo($secdate);
	exit(5); // less than three months to security fixes only support
}
