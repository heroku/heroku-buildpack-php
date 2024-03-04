# Dev Center Article Generator Fixtures

In order to test the article generator properly, a reasonably complex platform repository is needed, and building that by hand is no fun at all.

Using a real repository as a fixture is also not great, since that's many hundreds or even thousands of kB of JSON.

Instead, create a reduced repo with most patch versions etc filtered away by piping a "real" `packages.json` into the `jq` program below.

The example filters out PHP series 7.4 and 8.3 to reduce size further, but `--arg ignorephp '$REGEX'` can be omitted entirely.

Note the use of `--tabs`, which shaves about 15 % off the file size (with `--compact`, it's about 35 %, but then the file is no longer readable and editable by hand, and eventual diffs become huge).

    jq --tabs --arg ignorephp '(7\.4|8\.3)' '
    # from top-level packages key
    .packages
    # turn all entries into array of k (package name) and v (list of versions of that package) pairs
    | to_entries
    # and map that list; key carries over, value (list of package versions) needs some work
    | map({key, value:
      .value
      # early cleanup to keep size down
      | map(
        # drop packages we do not care about (e.g. blackfire, libraries)
        select(
          .name == "heroku-sys/composer" or
          (.type | test("^heroku-sys-(php(-extension)?|webserver)$"))
        )
        # skip PHP version series (and their extensions) the user wants to ignore (via e.g.: --arg ignorephp '(7\.3|8\.3)')
        | select(
          (.type | test("^heroku-sys-php(-extension)?$") | not) or
          (
            (
              (.type | test("^heroku-sys-php$")) and
              // \b\B is an "impossible" default value that can never match
              (.version | test("^"+($ARGS.named.ignorephp // "\b\B")+"\\.") | not)
            ) or
            (
              // in extensions, we check against the requirement
              (.type | test("^heroku-sys-php-extension$")) and
              // \b\B is an "impossible" default value that can never match
              (.require."heroku-sys/php" | test("^"+($ARGS.named.ignorephp // "\b\B")+"\\.") | not)
            )
          )
        )
        # drop heavy keys we do not need
        | del(.dist.url, .extra, .time)
      )
      # group the versions into the series we want to get as a result
      # this map step is handling only items that are just different versions of the same package
      # so we do not have to worry about the package name, or whether the package type will suddenly change
      | group_by(
        if .type == "heroku-sys-php-extension" then
          # for extensions, we want e.g. "8.3" and "5" as the grouping keys for an extension version 5.0.6 for PHP 8.3
          (.require."heroku-sys/php" | split(".") | .[0:2]), (.version | split(".") | .[0:1])
        else
          # for everything else, we are fine with just two version parts (so we get PHP 8.1, 8.2; Composer 2.2, 2.6, etc)
          .version | split(".") | .[0:2]
        end
      )
      # now we map each of these groups, so e.g. all PHP 8.2s, all PHP 8.3s, all ext-foobar 5 for PHP 8.2, all ext-foobar 5 for PHP 8.3
      | map(
        # sort by version number
        sort_by(
          .version
          # split version parts into pieces
          | split(".")
          # convert to number so we can sort numerically
          | map(tonumber? // -1) # -1 for "beta" or "RC" suffixes
        )
        # get us only the latest version in the group
        | last
      )
      # flatten our version groups back into a single list
      | flatten(1)
    })
    # maybe now there are no package versions for a key, so we want to skip it entirely
    | map(select(.value | length > 0))
    # turn k/v pairs back into object
    | from_entries
    # restore outer packages wrapper
    | {packages: .}
    '

It might then be worth touching up a few final things by hand, for example:

- add a second x.y.z+1 version of some package
- tidy up Composers
- change an extension version for one stack from x.y.z to x.y-1.$random, in order to ensure footnotes and multiple-versions-in-one-cell output
