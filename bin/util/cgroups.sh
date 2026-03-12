#!/usr/bin/env bash

cgroup_util_find_mount_by_fstype() {
	local usage="Usage: ${FUNCNAME[0]} FSTYPE [MOUNTINFO_PATH]"
	# if MOUNTINFO_PATH is not given, then no -F is passed, and findmnt will read from the default OS location 
	# must specify --list explicitly or it might output tree parts after all...
	findmnt --list --noheadings --first-only -t "${1:?$usage}" -o target ${2:+-F "$2"}
}

cgroup_util_find_cgroup2_hierarchy_path() {
	local usage="Usage: ${FUNCNAME[0]} PROC_SELF_CGROUP_PATH"
	# We are expecting a cgroupv2 unified hierarchy entry:
	# 0::/
	(
		set -o pipefail
		grep '^0::/' "${1:?$usage}" | cut -d ":" -f 3- | head -n1
	)
}

# $1 is the mount root from /proc/self/mountinfo
# $2 is the mount-relative dir from /proc/self/cgroup
# $3 is the controller name
cgroup_util_check_cgroup2_controller() {
	local usage="Usage: ${FUNCNAME[0]} MOUNT CGROUP_HIERARCHY CONTROLLER"
	local retval=${2:?$usage}
	# strip trailing slash if present (it would also be if it was just "/")
	retval=${1:?$usage}${retval%/}
	if grep -Eqs '(^|\s)'"${3:?$usage}"'($|\s)' "${retval}/cgroup.controllers"; then
		echo "$retval"
		return 0
	else
		# so it captures the exit status of grep, otherwise it is that of the if
		return
	fi
}

# this reads memory.high first, then falls back to memory.max, memory.low, or memory.min
cgroup_util_read_cgroup2_memory_limit() {
	local usage="Usage: ${FUNCNAME[0]} PATH"
	
	local f
	local limit
	# memory.high is the the best limit to read ("This is the main mechanism to control memory usage of a cgroup.", https://www.kernel.org/doc/html/v5.15/admin-guide/cgroup-v2.html)
	# we fall back to memory.max first (the final "safety net" limit), then memory.low (best-effort memory protection, e.g. OCI memory.reservation or Docker --memory-reservation), then finally memory.min (hard guaranteed minimum)
	for f in "${1:?$usage}/memory.high" "${1}/memory.max" "${1}/memory.low" "${1}/memory.min"; do
		if [[ ! -r "$f" ]]; then
			[[ -n ${CGROUP_UTIL_VERBOSE-} ]] && echo "Could not read a cgroup2 memory limit from '${f}'" >&2
			return 6
		fi
		limit=$(cat "$f")
		if [[ "$limit" != "max" && "$limit" != "0" ]]; then
			[[ -n ${CGROUP_UTIL_VERBOSE-} ]] && echo "Using limit from '${f}'" >&2
			echo "$limit"
			return
		fi
	done
	
	return 9
}

# finds a cgroup v2 (memory.high, fallback to memory.max, fallback to memory.low, fallback to memory.min) memory limit
# if env var CGROUP_UTIL_PROCFS_ROOT is passed, it will be used instead of '/proc' to find '/proc/self/cgroup', '/proc/self/mountinfo' etc (useful for testing, defaults to what 'findmnt' returns)
# if env var CGROUP_UTIL_CGROUPFS_PREFIX is passed, it will be prepended to any /sys/fs/cgroup or similar path used (useful for testing, defaults to '')
# pass a value for env var CGROUP_UTIL_VERBOSE to enable verbose mode
cgroup_util_find_cgroup2_memory_limit() {
	if [[ -z "${CGROUP_UTIL_PROCFS_ROOT-}" ]]; then
		# not passing a mountinfo location so that 'findmnt' can do its default thing
		local CGROUP_UTIL_PROCFS_ROOT
		CGROUP_UTIL_PROCFS_ROOT=$(cgroup_util_find_mount_by_fstype "proc") || {
			[[ -n ${CGROUP_UTIL_VERBOSE-} ]] && echo "Could not find procfs mount" >&2
			return 2
		}
	fi
	
	local cgroup2_mount
	cgroup2_mount=$(cgroup_util_find_mount_by_fstype "cgroup2" "${CGROUP_UTIL_PROCFS_ROOT}/self/mountinfo") || {
		[[ -n ${CGROUP_UTIL_VERBOSE-} ]] && echo "Could not determine mount point for cgroup2 file system from '${CGROUP_UTIL_PROCFS_ROOT}/self/mountinfo'" >&2
		return 3
	}
	# for testing purposes, a prefix can be passed to "relocate" the /sys/fs/cgroup/... location we are reading from next
	cgroup2_mount="${CGROUP_UTIL_CGROUPFS_PREFIX-}${cgroup2_mount}"
	
	local cgroup2_hierarchy_path
	cgroup2_hierarchy_path=$(cgroup_util_find_cgroup2_hierarchy_path "${CGROUP_UTIL_PROCFS_ROOT}/self/cgroup") || {
		[[ -n ${CGROUP_UTIL_VERBOSE-} ]] && echo "Could not determine path for cgroup2 unified hierarchy from '${CGROUP_UTIL_PROCFS_ROOT}/self/cgroup'" >&2
		return 4
	}
	
	local controller=memory
	
	local location
	location=$(cgroup_util_check_cgroup2_controller "$cgroup2_mount" "$cgroup2_hierarchy_path" "$controller") || {
		[[ -n ${CGROUP_UTIL_VERBOSE-} ]] && echo "Could not find a location for cgroup controller '${controller}'" >&2
		return 5
	}
	
	[[ -n ${CGROUP_UTIL_VERBOSE-} ]] && echo "Reading cgroup2 ${controller} limits from '${location}'" >&2
	
	local limit
	limit=$("cgroup_util_read_cgroup2_memory_limit" "$location") || return
	
	cgroup_util_filter_memory_limit "$limit"
}

cgroup_util_filter_memory_limit() {
	local limit=${1:?"Usage: ${FUNCNAME[0]} LIMIT_IN_BYTES"}
	# this value is used as a threshold for "silly" maximums returned e.g. by Docker on a cgroupv1 system
	local maximum=$((8 * 1024 * 1024 * 1024 * 1024)) # 8 TB
	
	if (( maximum > 0 && limit <= maximum )); then
		echo "$limit"
		return
	else
		[[ -n ${CGROUP_UTIL_VERBOSE-} ]] && echo "Ignoring limit of ${limit} Bytes (exceeds maximum of ${maximum} Bytes)" >&2
		return 99
	fi
}

# reads a cgroup v2 (memory.high, fallback to memory.max, fallback to memory.low, fallback to memory.min) memory limit, with fallback
# optional argument is a file path to fall back to for reading a default value, useful e.g. when reading on a system that has a "fake" limit info file (defaults to '/sys/fs/cgroup/memory/memory.limit_in_bytes')
# if env var CGROUP_UTIL_PROCFS_ROOT is passed, it will be used instead of '/proc' to find '/proc/self/cgroup', '/proc/self/mountinfo' etc (useful for testing, defaults to '/proc')
# if env var CGROUP_UTIL_CGROUPFS_PREFIX is passed, it will be prepended to any /sys/fs/cgroup or similar path used (useful for testing, defaults to '')
# pass a value for env var CGROUP_UTIL_VERBOSE to enable verbose mode
cgroup_util_find_cgroup2_memory_limit_with_fallback() {
	local fallback=${1-"${CGROUP_UTIL_CGROUPFS_PREFIX-}/sys/fs/cgroup/memory/memory.limit_in_bytes"}
	
	cgroup_util_find_cgroup2_memory_limit || {
		local retval=$?
		
		if ((retval != 99)) && [[ -r "$fallback" ]]; then
			[[ -n ${CGROUP_UTIL_VERBOSE-} ]] && echo "Reading fallback limit from '${fallback}'" >&2
			cgroup_util_filter_memory_limit "$(cat "$fallback")"
			return
		fi
		
		return "$retval"
	}
}
