#!/bin/bash

set -e

if [ "$NEWRELIC_VERSION" == "" ]; then
  echo "must set NEWRELIC_VERSION, i.e NEWRELIC_VERSION=2.8.5.73"
  exit 1
fi

basedir="$( cd -P "$( dirname "$0" )" && pwd )"

# make a temp directory
tempdir="$( mktemp -t newrelic_XXXX )"
installdir=$tempdir/install
rm -rf $tempdir
mkdir -p $tempdir
pushd $tempdir

# download and extract
curl -L "http://download.newrelic.com/php_agent/archive/${NEWRELIC_VERSION}/newrelic-php5-${NEWRELIC_VERSION}-linux.tar.gz" -o - | tar xz
pushd newrelic-php5-${NEWRELIC_VERSION}-linux
mkdir -p $installdir/{bin,etc} $installdir/var/{run,log} $installdir/var/log/newrelic
cp -f daemon/newrelic-daemon.x64 $installdir/bin/newrelic-daemon
cp -f scripts/newrelic.cfg.template $installdir/etc/newrelic.cfg
sed -i -e 's|var|app/local/var|g' $installdir/etc/newrelic.cfg
sed -i -e 's|#ssl=false|ssl=true|g' $installdir/etc/newrelic.cfg
curl -L "https://raw.github.com/gist/2767604/newrelic-license.sh" -o $installdir/bin/newrelic-license
chmod +x $installdir/bin/newrelic-license
popd

pushd $installdir
tar czf $tempdir/newrelic-${NEWRELIC_VERSION}-heroku.tar.gz .
popd

popd

cp $tempdir/newrelic-${NEWRELIC_VERSION}-heroku.tar.gz .

echo "+ Binaries available at ./newrelic-${NEWRELIC_VERSION}-heroku.tar.gz."
echo "+ Upload this package to Amazon S3."

# upload to s3
#s3cmd put -rr ./libmemcached-$LIBMEMCACHED_VERSION.tar.gz s3://$S3_BUCKET
