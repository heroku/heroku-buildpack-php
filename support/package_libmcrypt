#!/bin/bash

set -e

if [ "$LIBMCRYPT_VERSION" == "" ]; then
  echo "must set LIBMCRYPT_VERSION, i.e LIBMCRYPT_VERSION=2.5.8"
  exit 1
fi

basedir="$( cd -P "$( dirname "$0" )" && pwd )"

# make a temp directory
tempdir="$( mktemp -t libmcrypt_XXXX )"
rm -rf $tempdir
mkdir -p $tempdir
pushd $tempdir

# download and extract libmcrypt
curl -L "http://downloads.sourceforge.net/project/mcrypt/Libmcrypt/${LIBMCRYPT_VERSION}/libmcrypt-${LIBMCRYPT_VERSION}.tar.bz2?r=&ts=1337060759&use_mirror=nchc" -o - | tar xj

# build and package libmcrypt for heroku
vulcan build -v -s libmcrypt-$LIBMCRYPT_VERSION -o $tempdir/libmcrypt-$LIBMCRYPT_VERSION.tar.gz -p /app/local -c './configure --prefix=/app/local --disable-rpath && make install' 

popd

cp $tempdir/libmcrypt-$LIBMCRYPT_VERSION.tar.gz .

echo "+ Binaries available at ./libmcrypt-$LIBMCRYPT_VERSION.tar.gz"
echo "+ Upload this package to Amazon S3."

# upload to s3
#s3cmd put -rr $tempdir/*.tar.gz s3://$S3_BUCKET
