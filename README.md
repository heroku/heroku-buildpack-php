# Heroku Buildpack PHP with Snowflake Driver

This is the official [Heroku buildpack](http://devcenter.heroku.com/articles/buildpacks) for PHP applications with adjustments to build [Snowflake PDO](https://github.com/snowflakedb/pdo_snowflake) driver.

It uses Composer for dependency management, supports PHP or HHVM (experimental) as runtimes, and offers a choice of Apache2 or Nginx web servers.

## Usage

1. On your `app.json` you will need to add this repo git address as a buildpack
2. You may need to edit the file `bin/snowflake.sh` and adjust the extension folder address of your setup. `phpinfo()` will tell you the correct folder address.


## Update process


### Updating Snowflake

1. Add the original repo as "upstream":
    `git remote add upstream https://github.com/snowflakedb/pdo_snowflake.git`
2. Fetch all branches of remote upstream
    `git fetch upstream`
3. Rewrite your master with latest tag version
    `git rebase upstream/main`
4. Sync changes to retrieve the new data. Check if bin/snowflake.sh is in place
5. Add the followin code to `bin/compile` just above the row `status "Preparing runtime environment..."`
    `# snowflake
    source $bp_dir/bin/snowflake.sh`
6. Add the following lines to `conf/php/php.ini`
    `extension=pdo_snowflake.so
    pdo_snowflake.cacert=cacert.pem`
7. Update `conf/php/cacert.pem` with content from `https://github.com/gisle/mozilla-ca/blob/master/lib/Mozilla/CA/cacert.pem`
8. Commit and push to main


### Updating PHP Buildpack

1. Add the original repo as "upstream":
    `git remote add upstream https://github.com/heroku/heroku-buildpack-php.git`
2. Fetch all branches of remote upstream
    `git fetch upstream`
3. Rewrite your master with latest tag version
    `git rebase upstream/main`
4. Sync changes to retrieve the new data. Check if bin/snowflake.sh is in place. If PHP version changed, need to change the extension name dir to reflect the PHP API version. You may retrieve the PHP API version with the command `php -i | grep 'PHP API'`
5. Add the followin code to `bin/compile` just above the row `status "Preparing runtime environment..."`
    `# snowflake
    source $bp_dir/bin/snowflake.sh`
6. Add the following lines to `conf/php/php.ini`
    `extension=pdo_snowflake.so
    pdo_snowflake.cacert=cacert.pem`
7. Update `conf/php/cacert.pem` with content from `https://github.com/gisle/mozilla-ca/blob/master/lib/Mozilla/CA/cacert.pem`
8. Commit and push to main