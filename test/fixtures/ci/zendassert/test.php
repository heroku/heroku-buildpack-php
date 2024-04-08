<?php

ini_set("assert.exception", 1);

try {
	assert(true == false, "Expected true to be false");
	exit(1);
} catch(AssertionError $e) {
	fputs(STDERR, "Caught expected AssertionError");
}
