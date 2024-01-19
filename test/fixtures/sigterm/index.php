<?php

// we can't simply use sleep() because signals will interrupt that
function wait($wait = 1)
{
	$nano = 0;
	while(($res = time_nanosleep($wait, $nano)) !== true) {
		if($res === false) die("uhm, wat?");
		$wait = $res["seconds"];
		$nano = $res["nanoseconds"];
		file_put_contents("php://stderr", sprintf("signal interrupted, resuming nanosleep with %s.%s us remaining\n", $wait, $nano));
	};
}

$wait = (int)($_GET['wait']??5);
$start = hrtime(true);
wait($wait);

printf("hello world after %s us (expected %s s)\n", hrtime(true)-$start, $wait);

file_put_contents("php://stderr", "request complete");
