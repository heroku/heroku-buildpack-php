#!/bin/sh

. ${BUILDPACK_TEST_RUNNER_HOME}/lib/test_utils.sh

testDetect()
{
	mkdir -p ${BUILD_DIR}/
	touch ${BUILD_DIR}/index.php

	detect

	assertCapturedSuccess
	assertAppDetected "PHP"
}

testNoDetectPHP()
{
	mkdir -p ${BUILD_DIR}/

	detect

	assertCapturedError 1 "no"
	assertNoAppDetected
}
