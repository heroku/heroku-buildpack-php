#!/bin/sh

. ${BUILDPACK_TEST_RUNNER_HOME}/lib/test_utils.sh

. ${BUILDPACK_HOME}/support/set-env.sh

testCompile()
{
	compile

	assertCapturedSuccess

	assertCaptured "-----> Installing Nginx"
	assertCaptured "-----> Bundling Nginx v${NGINX_VERSION}"
	assertTrue "nginx should be executable" "[ -x ${BUILD_DIR}/vendor/nginx/sbin/nginx ]"

	assertCaptured "-----> Installing libmcrypt"
	assertCaptured "-----> Bundling libmcrypt v${LIBMCRYPT_VERSION}"
	assertTrue "libmcrypt should exist" "[ -e ${BUILD_DIR}/local/lib/libmcrypt.so ]"

	assertCaptured "-----> Installing libmemcached"
	assertCaptured "-----> Bundling libmemcached v${LIBMEMCACHED_VERSION}"
	assertTrue "libmemcached should exist" "[ -e ${BUILD_DIR}/local/lib/libmemcached.so ]"

	assertCaptured "-----> Installing PHP"
	assertCaptured "-----> Bundling PHP v${PHP_VERSION}"
	assertTrue "php-fpm should be executable" "[ -x ${BUILD_DIR}/vendor/php/sbin/php-fpm ]"

	assertCaptured "-----> Installing newrelic"
	assertCaptured "-----> Bundling newrelic daemon v${NEWRELIC_VERSION}"
	assertTrue "newrelic-daemon should be executable" "[ -x  ${BUILD_DIR}/local/bin/newrelic-daemon ]"

	assertCaptured "-----> Copying config files"
	assertTrue "php-fpm.conf exists and readable" "[ -r ${BUILD_DIR}/vendor/php/etc/php-fpm.conf ]"
	assertTrue "php.ini exists and readable" "[ -r ${BUILD_DIR}/vendor/php/php.ini ]"
	assertTrue "php/etc.d/ directory exists" "[ -d ${BUILD_DIR}/vendor/php/etc.d/ ]"
	assertTrue "nginx.conf.erb exists and readable" "[ -r ${BUILD_DIR}/vendor/nginx/conf/nginx.conf.erb ]"

	assertCaptured "-----> Installing boot script"
	assertTrue "boot.sh exists and executable" "[ -x ${BUILD_DIR}/boot.sh ]"

	assertCaptured "-----> Done with compile"
}
