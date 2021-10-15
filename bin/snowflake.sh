#!/bin/bash
# Build Path: /app/.heroku/php/
#dep_url=git://github.com/snowflakedb/pdo_snowflake.git
dep_url=git://github.com/studiohyperset/pdo_snowflake.git
snowflake_dir=pdo_snowflake
echo "-----> Building Snowflake..."

### Phalcon
echo "[LOG] Downloading Snowflake"
git clone $dep_url -q
if [ ! -d "$snowflake_dir" ]; then
  echo "[ERROR] Failed to find snowflake directory $snowflake_dir"
  exit
fi
echo "[LOG] Setting PHP_HOME"
export PHP_HOME=$1

echo "[LOG] Building Snowflake"
bash $snowflake_dir/scripts/build_pdo_snowflake.sh

#echo "[LOG] Checking if in memory"
#$PHP_HOME/bin/php -dextension=modules/pdo_snowflake.so -m | grep pdo_snowflake

echo "[DEBUG] PHP_HOME=$PHP_HOME"
echo "[DEBUG] SNOWFLAKE DIR=$snowflake_dir"
echo "[LOG] Copying PDO Snowflake to Extensions Folder"
cp $PHP_HOME/pdo_snowflake/modules/pdo_snowflake.so /app/.heroku/php/lib/php/extensions/no-debug-non-zts-20190902

echo "[LOG] Copying cacert to configuration folder"
cp $snowflake_dir/libsnowflakeclient/cacert.pem /app/.heroku/php/etc/php/

echo "[LOG] Creating snowflake.ini"
echo "[LOG] Inserting extension and certificate on snowflake.ini"
echo "extension=pdo_snowflake.so" > /app/.heroku/php/etc/php/conf.d/20-pdo_snowflake.ini 
echo "pdo_snowflake.cacert=/app/.heroku/php/etc/php/cacert.pem" >> /app/.heroku/php/etc/php/conf.d/20-pdo_snowflake.ini 

echo "[LOG] Finished Snowflake Setup"