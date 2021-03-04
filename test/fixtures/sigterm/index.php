<?php

$wait = (int)($_GET['wait']??0);

sleep($wait);

echo "hello world after $wait second(s)\n";

file_put_contents("php://stderr", "request complete");
