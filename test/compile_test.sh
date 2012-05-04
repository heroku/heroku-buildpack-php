#!/bin/sh

. ${BUILDPACK_TEST_RUNNER_HOME}/lib/test_utils.sh

testCompile() {
  touch ${BUILD_DIR}/index.php
 
  compile
  assertCapturedSuccess
  assertCaptured "Bundling Apache"
  assertTrue "Apache should be installed" "[ -d ${BUILD_DIR}/apache ]"
  assertTrue "Apache config should be copied" "[ -f ${BUILD_DIR}/apache/conf/httpd.conf ]"
  assertTrue "Apache should include mod_expires module" "[ -f ${BUILD_DIR}/apache/modules/mod_expires.so ]"
  assertTrue "Apache should include mod_headers module" "[ -f ${BUILD_DIR}/apache/modules/mod_headers.so ]"
  assertFileContains "Apache should load include expires_module" "LoadModule expires_module" "${BUILD_DIR}/apache/conf/httpd.conf" 
  assertFileContains "Apache should load include headers_module" "LoadModule headers_module" "${BUILD_DIR}/apache/conf/httpd.conf" 

  assertCaptured "Bundling PHP"
  assertTrue "PHP should be installed" "[ -d ${BUILD_DIR}/php ]"
  assertTrue "PHP config should be copied" "[ -f ${BUILD_DIR}/php/php.ini ]"
  assertTrue "PHP should include Redis extension" "[ -f ${BUILD_DIR}/php/ext/redis.so ]"
  assertFileContains "PHP should load Redis extension" "extension=redis.so" "${BUILD_DIR}/php/php.ini"

  assertTrue "bin dir should be created" "[ -d ${BUILD_DIR}/bin ]"
  assertTrue "boot.sh dir should be created and be executable" "[ -x ${BUILD_DIR}/boot.sh ]"
  assertEquals "cache should be cleared" "" "$(ls ${CACHE_DIR})"
}
