#!/bin/sh

. ${BUILDPACK_TEST_RUNNER_HOME}/lib/test_utils.sh

testNoDetect() {
  detect

  assertNoAppDetected
}

testDetect_PHP() {
  touch ${BUILD_DIR}/index.php
  
  detect

  assertAppDetected "PHP"
}
