# Minimal Laravel 11 with ScoutAPM integration

This fixture is a minimal Laravel 11 app with the `scoutapp/scoutapm-php-laravel` package.

The purpose is to ensure that this package does not automatically download and start the ScoutAPM `core-agent` program during a build.

## Prerequisites

To do something with this project locally (unless you're only running e.g. `composer update` with `--no-scripts`), make sure there is a `.env` file with the following contents:

```dotenv
CACHE_STORE=array
LOG_CHANNEL=stderr
```

This will allow Laravel to start up correctly, but will not cause the ScoutAPM package to download and run the `core-agent` program unless the necessary environment variables are set (see next section).

## On Heroku

To use this as a test case on Heroku, the following config vars are needed:

```dotenv
CACHE_STORE=array
LOG_CHANNEL=stderr
SCOUT_KEY=test
SCOUT_MONITOR=true
SCOUT_NAME=test
```

## How to (re-)create this project from scratch

> [!IMPORTANT]
> You need a `bash -O extglob -O dotglob` session for the glob patterns below to work!

### 1. Make a new skeleton project

> [!NOTE]
> This uses Laravel 11, because `scoutapp/scout-apm-laravel` is currently not compatible with newer versions.

1. Inside `test/fixtures/bugs/`, make a new project based on Laravel 11:
   ```ShellSession
   $ composer create-project --no-scripts laravel/laravel:^11.0 scoutapm/
   $ cd scoutapm/
   ```
2. Inside `scoutapm/`, stage and commit the current state (we will amend this commit later):
   ```ShellSession
   $ git add .
   $ git commit -m "import Laravel skeleton"
   ```

### 3. Trim down the `scoutapm/` directory contents

1. Remove everything except `.gitignore`, `artisan`, `bootstrap/`, `composer.json`, `composer.lock`, and any untracked files(we clean those up at the end):
   ```ShellSession
   $ git rm -r !(.gitignore|artisan|bootstrap|composer.json|composer.lock$(git check-ignore -- * | xargs printf "|%s"))
   ```
1. Remove the `--withRouting` part from `boostrap/app.php`:
   ```diff
   diff --git a/bootstrap/app.php b/bootstrap/app.php
   index 7b162da..43175b5 100644
   --- a/bootstrap/app.php
   +++ b/bootstrap/app.php
   @@ -5,11 +5,6 @@ use Illuminate\Foundation\Configuration\Exceptions;
    use Illuminate\Foundation\Configuration\Middleware;
    
    return Application::configure(basePath: dirname(__DIR__))
   -    ->withRouting(
   -        web: __DIR__.'/../routes/web.php',
   -        commands: __DIR__.'/../routes/console.php',
   -        health: '/up',
   -    )
        ->withMiddleware(function (Middleware $middleware) {
            //
        })
   ```
1. Remove the local service provider from `bootstrap/providers.php`:
   ```diff
   diff --git a/bootstrap/providers.php b/bootstrap/providers.php
   index 38b258d..b625128 100644
   --- a/bootstrap/providers.php
   +++ b/bootstrap/providers.php
   @@ -1,5 +1,4 @@
    <?php
    
    return [
   -    App\Providers\AppServiceProvider::class,
    ];
   ```
1. Strip down `composer.json` so that only two sections remain:
   1. `require` with two entries:
      - `php`
      - `laravel/framework`
   1. `scripts` with two entries under `post-autoload-dump`:
      - `Illuminate\\Foundation\\ComposerScripts::postAutoloadDump`
      - `@php artisan package:discover --ansi`
1. Re-generate the lock file:
   ```ShellSession
   $ composer update --no-scripts
   ```
1. Stage and commit the modifications, amending the previous commit:
   ```ShellSession
   $ git add bootstrap/ composer.*
   $ git commit --amend -m "import and trim Laravel skeleton"
   ```

> [!IMPORTANT]
> Using `--amend` in such a case helps keep the repository size small

### 4. Add the Scout Laravel APM Agent

> [!NOTE]
> When prompted whether to trust the `php-http/discovery` plugin, choose yes

> [!TIP]
> If your local PHP version is not compatible, you can use `--ignore-platform-req=php` with `composer require`

1. Add package `scoutapp/scout-apm-laravel`:
   ```ShellSession
   $ composer require --no-scripts scoutapp/scout-apm-laravel
   ```
1. The `php artisan vendor:publish --provider="Scoutapm\Laravel\Providers\ScoutApmServiceProvider"` step is not necessary,because we are using `CACHE_STORE=array`
1. Stage and commit the modifications:
   ```ShellSession
   $ git add composer.*
   $ git commit -m "add scoutapp/scout-apm-laravel"
   ```
1. Clean up:
   ```ShellSession
   $ git clean -xi .
   ```

> [!NOTE]
> The `git clean` step will remove any untracked files, as well as ignored files (e.g. `.env`, `vendor`, `bootstrap/cache/*`).
