# Linux cgroups Test Fixtures

These fixtures represent various correct, broken, or "hacked" container environments that expose Linux Control Groups information in `/proc` and `/sys/fs/cgroup`.

## Fixture Structure

Each fixture subdir contains the following, extracted from a real container environment:

- `expected_status` (optional)
- `expected_stdout` (optional)
- `expected_stderr` (optional)
- `proc/self/cgroup` (the contents of `/proc/self/cgroup`)
- `proc/self/mountinfo` (the contents of `/proc/self/mountinfo`)
- `sys/fs/cgroup/_files.json` (the contents of all the files in `/sys/fs/cgroup` and its subdirectories as a JSON object, with absolute path as key and contents as value)

### Testing fallback behavior

For testing the behavior of reading info with a fallback to e.g a legacy cgroup v1 info file, you can optionally use:
- `expected_status_with_fallback` (optional)
- `expected_stdout_with_fallback` (optional)
- `expected_stderr_with_fallback` (optional)

### Matching stdout and stderr messages

Use "`%1$s`" in cases where you want to match against the tmpdir path prefix used for the test case's cgroup directory (expanded from `_files.json`), and "`%2$s`" to match against the test fixture path (which contains e.g. `proc/self/mountinfo`). For example:

```
Could not determine mount point for cgroup2 file system from '%2$s/proc/self/mountinfo'
Reading fallback limit from '%1$s/sys/fs/cgroup/memory/memory.limit_in_bytes'
```

### Note on `_files.json`

`sys/fs/cgroup/_files.json` is used by the unit tests to build a temporary directory of cgroup contents, without needing all the individual files expanded in the repository.

## Fixtures

### General

Several fixtures test basic cgroup structures and limits, missing memory controllers, various limit types, etc, as well as intentionally broken stuff like an inaccessible procfs or unreadable memory controllers (for error handling tests).

### Heroku

- `heroku-cr-slugs`: Heroku Common Runtime test case for classic cgroupsv1 "emulation" via written-out `/sys/fs/cgroup/memory/memory.limit_in_bytes` file and no `cgroup2` mount
- `heroku-ps-slugs`: Heroku Private Spaces test case for classic cgroupsv1 "emulation" via written-out `/sys/fs/cgroup/memory/memory.limit_in_bytes` file and no `cgroup2` mount

## Generating fixtures with Docker

Running the script `test/fixtures/cgroup/gen-docker-cases.sh` (from the root dir of the buildpack) generates `test/fixtures/cgroup/docker-…` cases using the currently configured Docker cgroup driver and version (which it gets from `docker info`).

These should not be committed to the repo, as not all permutations are needed, but it can be used as a starting point for building or updating other fixtures.

The generated fixture directories have the following name structure: `docker-${cgroup_driver}-v${cgroup_version}-${cgroup_ns}-${cgroup_parent}-${mem_res}-${mem_limit}`

Where:
- `${cgroup_driver}` can be one of `cgroupfs` or `systemd` (the latter isn't currently used because it needs a systemd enabled OS)
- `${cgroup_version}` is either `1` or `2`
- `${cgroup_ns}` is either `host` or `private`, depending on the `--cgroupns` option of `docker run`
- `${cgroup_parent}` is either `parent`, `parentwithcolon` or `noparent`, depending on the `--cgroup-parent` option of `docker run` (for the `parentwithcolon` case, the option value contains a colon, to test e.g. the correct splitting of the colon-separated `/proc/self/cgroup` table)
- `${mem_res}` is either `res` or `nores`, depending on the `--memory-reservation` option of `docker run`
- `${mem_limit}` is either `limit` or `nolimit`, depending on the `-m` option of `docker run`

The cgroup driver for Docker can be controlled via `~/.docker/daemon.json`, like so (values can be `systemd` or `cgroupfs`):
```json
{
  …
  "exec-opts": ["native.cgroupdriver=systemd"]
  …
}
```

The cgroup version for Docker can be controlled via `~/Library/Group Containers/group.com.docker/settings.json` key `deprecatedCgroupv1` (setting it to `true` switches to cgroups v1):

```json
{
  …
  "deprecatedCgroupv1": false,
  …
```
