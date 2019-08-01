<?php

function helloWorld() {
	return "Hello Worldx";
}

describe("Hello World", function() {
	it("greets", function() {
		assert(helloWorld() == "Hello World", "expected Hello World");
	});
});
