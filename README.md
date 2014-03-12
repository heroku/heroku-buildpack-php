# Heroku PHP buildpack

This is a build pack bundling PHP for Heroku apps. Currently very alpha.

## Usage

Please refer to [Dev Center](https://devcenter.heroku.com/categories/php) for usage instructions.

## Development

### Compiling Binaries

The folder `support/build` contains [Hammer](https://github.com/hone/hammer) build scripts for all dependencies.

To get started with Hammer:

    $ gem install --prerelease hammer

Then, in each folder inside `support/build`, run:

    $ hammer build

to easily build the respective component using Anvil on Heroku infrastructure.

Resulting packages will be placed inside the `builds/` subfolder of each component and can be uploaded to a public location (e.g. S3 or Dropbox).

The URI of this upload is referenced inside `bin/compile`.

### Hacking

To work on this buildpack, fork it on Github. You can then use [Anvil with a local buildpack](https://github.com/heroku/anvil-cli#iterate-on-buildpacks-without-pushing-to-github) to easily iterate on changes without pushing each time.

Alternatively, you may push changes to your fork (ideally in a branch if you'd like to submit pull requests), then create a test app with `heroku create --buildpack <your-github-url#branch>` and push to it.
