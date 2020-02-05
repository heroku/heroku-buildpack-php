<?php

function helloWorld() {
	return "Hello World";
}

describe("Hello World", function() {
	it("greets", function() {
		expect(helloWorld())->toEqual("Hello World");
	});
});