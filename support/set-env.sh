#!/bin/bash

export S3_BUCKET="heroku-buildpack-php-tyler"

export LIBMCRYPT_VERSION="2.5.8"
export PHP_VERSION="5.4.8"
export APC_VERSION="3.1.10"
export PHPREDIS_VERSION="2.2.2"
export LIBMEMCACHED_VERSION="1.0.7"
export MEMCACHED_VERSION="2.0.1"
export NEWRELIC_VERSION="2.9.5.78"

export NGINX_VERSION="1.2.5"

export EC2_PRIVATE_KEY=~/.ec2/pk.pem
export EC2_CERT=~/.ec2/cert.pem
export EC2_URL=https://ec2.us-east-1.amazonaws.com
