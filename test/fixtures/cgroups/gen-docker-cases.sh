#!/usr/bin/env bash

cgroup_driver=$(set -o pipefail; docker info | grep 'Cgroup Driver' | cut -f2 -d":" | xargs) || {
	echo >&2 "Failed to read 'Cgroup Driver' from 'docker info'"
	exit 1
}

echo >&2 "Docker 'Cgroup Driver' (from 'docker info') is: ${cgroup_driver}"
echo >&2 "You can switch by setting 'exec-opts' to '[\"native.cgroupdriver=cgroupfs\"]' or '[\"native.cgroupdriver=systemd\"]' in '~/.docker/daemon.json'"
echo >&2 "Remember to quit and start Docker Desktop afterwards (just a restart is not enough)"

cgroup_version=$(set -o pipefail; docker info | grep 'Cgroup Version' | cut -f2 -d":" | xargs) || {
	echo >&2 "Failed to read 'Cgroup Version' from 'docker info'"
	exit 1
}

echo >&2 "Docker 'Cgroup Version' (from 'docker info') is: ${cgroup_version}"
echo >&2 "You can switch by changing 'deprecatedCgroupv1' in '~/Library/Group Containers/group.com.docker/settings.json'"
echo >&2 "Remember to quit and start Docker Desktop afterwards (just a restart is not enough)"

img=heroku/heroku:24
# "1024M" and "800M" are grepped further down, be careful with changes
cases=(
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-host-noparent-res-limit -m 1024M --memory-reservation 800M --cgroupns host"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-private-noparent-res-limit -m 1024M --memory-reservation 800M --cgroupns private"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-host-noparent-nores-limit -m 1024M --cgroupns host"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-private-noparent-nores-limit -m 1024M --cgroupns private"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-host-noparent-res-nolimit --memory-reservation 800M --cgroupns host"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-private-noparent-res-nolimit --memory-reservation 800M --cgroupns private"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-host-noparent-nores-nolimit --cgroupns host"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-private-noparent-nores-nolimit --cgroupns private"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-host-parent-res-limit -m 1024M --memory-reservation 800M --cgroupns host --cgroup-parent test123"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-private-parent-res-limit -m 1024M --memory-reservation 800M --cgroupns private --cgroup-parent test123"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-host-parent-nores-limit -m 1024M --cgroupns host --cgroup-parent test123"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-private-parent-nores-limit -m 1024M --cgroupns private --cgroup-parent test123"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-host-parent-res-nolimit --memory-reservation 800M --cgroupns host --cgroup-parent test123"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-private-parent-res-nolimit --memory-reservation 800M --cgroupns private --cgroup-parent test123"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-host-parent-nores-nolimit --cgroupns host --cgroup-parent test123"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-private-parent-nores-nolimit --cgroupns private --cgroup-parent test123"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-host-parentwithcolon-res-limit -m 1024M --memory-reservation 800M --cgroupns host --cgroup-parent test123:oopsie"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-private-parentwithcolon-res-limit -m 1024M --memory-reservation 800M --cgroupns private --cgroup-parent test123:oopsie"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-host-parentwithcolon-nores-limit -m 1024M --cgroupns host --cgroup-parent test123:oopsie"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-private-parentwithcolon-nores-limit -m 1024M --cgroupns private --cgroup-parent test123:oopsie"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-host-parentwithcolon-res-nolimit --memory-reservation 800M --cgroupns host --cgroup-parent test123:oopsie"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-private-parentwithcolon-res-nolimit --memory-reservation 800M --cgroupns private --cgroup-parent test123:oopsie"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-host-parentwithcolon-nores-nolimit --cgroupns host --cgroup-parent test123:oopsie"
	"test/fixtures/cgroups/docker-${cgroup_driver}-v${cgroup_version}-private-parentwithcolon-nores-nolimit --cgroupns private --cgroup-parent test123:oopsie"
)

for case in "${cases[@]}"; do
	parts=( $case ) # destructure string into bits
	case=${parts[0]} # first part is the case name/dir - caution: array indexing differs if you run this in zsh (starts at 1)
	opts=${parts[@]:1} # remaining parts are docker opts - caution: array indexing differs if you run this in zsh (starts at 1)
	echo "Populating ${case}..."
	# write these out so the test logic does not have to pull massive stunts in order to figure out which of the /sys/fs/cgroup subdirs has the expected value
	# --memory-reservation sets memory.low, so if there is a -m (memory.max) as well, that takes precedence
	echo "$opts" | grep -q -- "--memory-reservation 800M" && echo $(( 800 * 1024 * 1024 )) > "$case/expected_stdout"
	echo "$opts" | grep -q -- "-m 1024M" && echo $(( 1024 * 1024 * 1024 )) > "$case/expected_stdout"
	mkdir -p "$case/proc/self"
	mkdir -p "$case/sys/fs/cgroup"
	# no quotes for $opts is correct
	cname=cgroup-fixture-$(basename "$case")
	docker run --rm -di --name "$cname" $opts --cpuset-cpus 1-2 "$img"
	docker exec "$cname" bash -c 'cat /proc/cgroups' > "$case/proc/cgroups"
	docker exec "$cname" bash -c 'cat /proc/self/cgroup' > "$case/proc/self/cgroup"
	docker exec "$cname" bash -c 'cat /proc/self/mountinfo' > "$case/proc/self/mountinfo"
	docker exec "$cname" bash -c 'shopt -s globstar; for f in /sys/fs/cgroup/**; do [[ -f "$f" ]] && { echo "$f:"; cat $f; }; done' > "$case/sys/fs/cgroup/_files" 2>&1
	docker exec "$cname" bash -c 'shopt -s globstar; echo "{}" > /tmp/out.json; for f in /sys/fs/cgroup/**; do [[ -f "$f" ]] && cat "$f" 2>/dev/null | jq -nsR --slurpfile in /tmp/out.json --arg f "$f" '"'"'($in[0]) + {($f): input}'"'"' > /tmp/tmp.json; [[ -f /tmp/tmp.json ]] && mv /tmp/tmp.json /tmp/out.json; done; cat /tmp/out.json' > "$case/sys/fs/cgroup/_files.json"
	docker kill "$cname"
done
