# Heroku Buildpack: PHP + Laravel

![Laravel Buildpack](https://bosnadev.com/wp-content/uploads/2014/09/laravel_heroku.jpg)

Forked official [Heroku PHP Buildpack](https://github.com/heroku/heroku-buildpack-php) with added support for Laravel based applications.

## Usage

You'll need to use at least an empty `composer.json` in your application.

    echo '{}' > composer.json
    git add composer.json
    git commit -m "add composer.json for PHP app detection"

If you also have files from other frameworks or languages that could trigger another buildpack to detect your application as one of its own, e.g. a `package.json` which might cause your code to be detected as a Node.js application even if it is a PHP application, then you need to manually set your application to use this buildpack:

    heroku buildpacks:set https://github.com/gerardbalaoro/heroku-buildpack-laravel.git

Please refer to [Dev Center](https://devcenter.heroku.com/categories/php) for further usage instructions.

## Generating .env File
By default, this will replace the existing *.env* file. It will automatically populate the basic variables from your *Heroku Config Vars*.

    heroku config:set *VARIABLE_NAME*=*VALUE*
    heroku config:set APP_NAME=Laravel App

The following are the supported variables:
- APP_NAME
- APP_ENV
- APP_DEBUG
- APP_URL

For database configuration variables:
- DB_CONN (Database Driver)
- DB_HOST
- DB_PORT
- DB_USER
- DB_PASS
- DB_NAME (Database Name)

For email configuration variables:
- MAIL_DRIVER
- MAIL_HOST
- MAIL_USER
- MAIL_PASS
- MAIL_PORT

To run post deploy commands set config variable 
    
    heroku config:set DEPLOY_TASKS=php artisan migrate:refresh --force -seed
 
## Generating environment key
By default, this buildpack also runs `php artisan key:generate`.
