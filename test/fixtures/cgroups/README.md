# Linux cgroups Test Fixtures

These fixtures represent various correct, broken, or "hacked" container environments that expose Linux Control Groups information in `/proc` and `/sys/fs/cgroup`.

## Fixture Structure

Each fixture subdir contains the following, extracted from a real container environment:

- `expected_status` (optional)
- `expected_stdout` (optional)
- `expected_stderr` (optional; use "`%s`" in cases where you want to match against the tmpdir path prefix used for the test case)
- `proc/cgroups` (the contents of `/proc/cgroups`)
- `proc/self/cgroup` (the contents of `/proc/self/cgroup`)
- `proc/self/mountinfo` (the contents of `/proc/self/mountinfo`)
- `sys/fs/cgroup/_files` (the output of all the files in `/sys/fs/cgroup` and its subdirectories `cat`ed, concatenated together, with "`${filename}:`" headings before each `cat` output, which may contain "Permission denied" errors or similar)
- `sys/fs/cgroup/_files.json` (the contents of all the files in `/sys/fs/cgroup` and its subdirectories as a JSON object, with absolute path as key and contents as value)

### Note on `_files(.json)?`

The `sys/fs/cgroup/_files` file serves as a human-readable source of information for working with the fixtures. Its `sys/fs/cgroup/_files.json` equivalent is used for programmatically accessing contents of fixtures, without having all the individual files expanded.

Notably, the `test/fixtures/cgroup/expand-file-json.sh` script will expand the files whose basenames match the given patterns into each directory; this is useful to expand a subset of captured fixture contents for tests. All arguments will be passed as `-e` patterns to `grep`; to expand, for example, all cgroup v1 and v2 memory limit info files, including those for swap limits, one would run:

```
$ test/fixtures/cgroup/expand-file-json.sh '^memory\.(memsw\.|soft_)?limit_in_bytes$' '^memory\.(min|low|high|(swap\.)?max)$'
```

## Fixtures

### Docker

The fixture directories have the following name structure: `docker-${cgroup_driver}-v${cgroup_version}-${cgroup_ns}-${cgroup_parent}-${mem_res}-${mem_limit}`

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
  "deprecatedCgroupv1": true,
  …
```

Running the script `test/fixtures/cgroup/gen-docker-cases.sh` (from the root dir of the buildpack) generates the `test/fixtures/cgroup/docker-…` cases using the currently configured Docker cgroup driver and version (which it gets from `docker info`).

### Heroku

- `heroku-cr-v1`: Heroku Common Runtime test case for classic cgroupsv1 "emulation" via written-out `/sys/fs/cgroup/memory/memory.limit_in_bytes` file
- `heroku-cr-v2-r1`: Heroku Common Runtime test case for cgroupsv2 implementation revision 1, with `/sys/fs/cgroup/memory.high` having the container limit
- `heroku-ps-v1-crcompat`: Heroku Private Spaces test case for `heroku-cr-v1` compatibility
- `heroku-ps-v1-focal`: Heroku Private Spaces test case for hybrid cgroups v1/v2 controllers from before `heroku-ps-v1-crcompat`
- `heroku-ps-v2-r1`: Heroku Private Spaces test case for cgroupsv2 implementation revision 1, with `/sys/fs/cgroup/memory.max` having the container limit
