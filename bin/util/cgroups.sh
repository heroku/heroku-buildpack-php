#!/usr/bin/env bash

# stdin is the output of e.g. /proc/self/cgroup
cgroup_util_find_controller_from_procfs_cgroup() {
	local usage="Usage (stdin is /proc/self/cgroup format): ${FUNCNAME[0]} CONTROLLER"
	# there may be an entry for a v1 controller like:
	# 7:memory:/someprefix
	# if not, then there can be an entry for a v2 unified hierarchy, e.g.:
	# 0::/
	# we look for the v1 first, as there may be hybrid setups where some controllers are still v1
	# so if there is an entry for "memory", a v1 controller is in charge, even if others are v2
	(
		set -o pipefail
		grep -E -e '^[0-9]+:('"${1:?$usage}"')?:/.*' | sort -r -n -k 1 -t ":" | head -n1
	)
}

cgroup_util_get_controller_version_from_procfs_cgroup_line() {
	readarray -d':' -t line # -t removes trailing delimiter
	# with e.g. 'docker run --cgroup-parent foo:bar, the third (relative path) section would contain a colon
	if (( ${#line[@]} < 3 )); then
		exit 1
	fi
	if [[ ${line[0]} == "0" ]]; then
		echo "2"
	else
		echo "1"
	fi
}

cgroup_util_get_controller_path_from_procfs_cgroup_line() {
	readarray -d':' line # no -t, we want any trailing delims for concatenation via printf
	if (( ${#line[@]}  < 3 )); then
		exit 1
	fi
	# with e.g. 'docker run --cgroup-parent foo:bar, the third (relative path) section would contain a colon, so we have to output from 3 until the end
	printf "%s" "${line[@]:2}"
}

# stdin is the output of e.g. /proc/self/mountinfo
# $1 is a controller name, which is matched against the mount options using -O (so it could be a comma-separated list, too)
cgroup_util_find_v1_mount_from_procfs_mountinfo() {
	local usage="Usage (stdin is /proc/self/cgroup format): ${FUNCNAME[0]} CONTROLLER"
	# must specify --list explicitly or it might output tree parts after all...
	findmnt --list --noheadings --first-only -t cgroup -O "${1:?$usage}" -o target -F <(cat)
}

# stdin is the output of e.g. /proc/self/mountinfo
cgroup_util_find_v2_mount_from_procfs_mountinfo() {
	# must specify --list explicitly or it might output tree parts after all...
	findmnt --list --noheadings --first-only -t cgroup2 -o target -F <(cat)
}

# $1 is the controller name, $2 is the mount root from /proc/self/mountinfo, $3 is the mount relative dir from /proc/self/cgroup
cgroup_util_find_v1_path() {
	local usage="Usage: ${FUNCNAME[0]} CONTROLLER MOUNT CGROUP"
	local relpath=${3:?$usage}
	# strip trailing slash if present (it would also be if it was just "/")
	relpath=${relpath%/}
	cur="${2:?$usage}${relpath}"
	while true; do
		if [[ -d "$cur" ]] && compgen -G "${cur}/${1:?$usage}.*" > /dev/null; then
			echo "$cur"
			return 0
		elif [[ "$cur" == "$2" ]]; then
			break # we are at the mount, and it does not exist
		fi
		cur=$(dirname "$cur")
	done
	return 1
}

# $1 is the controller name, $2 is the mount root from /proc/self/mountinfo, $3 is the mount relative dir from /proc/self/cgroup
cgroup_util_find_v2_path() {
	local usage="Usage: ${FUNCNAME[0]} CONTROLLER MOUNT CGROUP"
	local retval=${3:?$usage}
	# strip trailing slash if present (it would also be if it was just "/")
	retval=${2:?$usage}${retval%/}
	if grep -Eqs '(^|\s)'"${1:?$usage}"'($|\s)' "${retval}/cgroup.controllers"; then
		echo "$retval"
		return 0
	else
		# so it captures the exit status of grep, otherwise it is that of the if
		return
	fi
}

# this ignores memory.soft_limit_in_bytes on purpose for the reasons outlined in https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html#id1
cgroup_util_read_cgroupv1_memory_limit() {
	local usage="Usage: ${FUNCNAME[0]} [-v] PATH"
	local verbose=
	
	# we must declare this as local, otherwise the caller's $OPTIND will be modified by getopts	
	local OPTIND
	while getopts ":v" opt; do
		case "$opt" in
			v)
				verbose=1
				;;
			\?)
				echo "Invalid option: -${OPTARG}" >&2
				return 2
				;;
			:)
				echo "Option -${OPTARG} requires an argument" >&2
				return 2
				;;
		esac
	done
	# clear processed arguments
	shift $((OPTIND-1))
	
	local usage="Usage: ${FUNCNAME[0]} PATH"
	local f="${1:?$usage}/memory.limit_in_bytes"
	if [[ -r "$f" ]]; then
		[[ $verbose ]] && echo "Using limit from '${f}'" >&2
		cat "$f"
		return
	else
		return 9
	fi
}

# this reads memory.high first, then falls back to memory.max, then falls back to memory.low unless -L is passed
cgroup_util_read_cgroupv2_memory_limit() {
	local usage="Usage: ${FUNCNAME[0]} [-Lv] PATH"
	local fallback_to_low=true # for an if later
	local verbose=
	
	# we must declare this as local, otherwise the caller's $OPTIND will be modified by getopts	
	local OPTIND
	while getopts ":Lv" opt; do
		case "$opt" in
			L)
				fallback_to_low=false
				;;
			v)
				verbose=1
				;;
			\?)
				echo "Invalid option: -${OPTARG}" >&2
				return 2
				;;
			:)
				echo "Option -${OPTARG} requires an argument" >&2
				return 2
				;;
		esac
	done
	# clear processed arguments
	shift $((OPTIND-1))
	
	local limit
	
	local f
	for f in "${1}/memory.high" "${1}/memory.max"; do
		if [[ -r "$f" ]]; then
			limit=$(cat "$f")
			if [[ "$limit" != "max" ]]; then
				[[ $verbose ]] && echo "Using limit from '${f}'" >&2
				echo "$limit"
				return
			fi
		fi
	done
	
	f="${1}/memory.low"
	if $fallback_to_low && [[ -r "$f" ]]; then
		limit=$(cat "$f")
		if [[ "$limit" != "0" ]]; then
			[[ $verbose ]] && echo "Using limit from '${f}'" >&2
			echo "$limit"
			return
		fi
	fi
	
	return 9
}

# reads a cgroup v1 (memory.limit_in_bytes) or v2 (memory.high, fallback to memory.max, fallback to memory.low)
# -L disables fallback to memory.low if memory.high and memory.max do not have a value (i.e. are "max"), e.g. when using 'docker run' with '--memory-reservation' but not '--memory'
# -m is the maximum memory to allow for any value (e.g. Docker may give 8 Exabytes for unlimited containers); no value is returned if this value is exceeded, and it defaults to the value read from "free"
# -p is the location of procfs, defaults to /proc (useful as an override for testing)
# -s is a prefix that will be prepended to found cgroupfs mount locations (useful for testing)
# -v is verbose mode
cgroup_util_read_cgroup_memory_limit() {
	local usage="Usage: ${FUNCNAME[0]} [-Lv] [-m MEMORY_MAXIMUM] [-p PROCFS_ROOT] [-s CGROUPFS_PREFIX]"
	
	local cgroupfs_prefix=
	local l= # for the ${l+:} check later
	local maximum
	local proc=/proc
	local verbose=
	
	# we must declare this as local, otherwise the caller's $OPTIND will be modified by getopts	
	local OPTIND
	while getopts ":Lm:p:s:v" opt; do
		case "$opt" in
			L)
				l=false
				;;
			m)
				maximum=$OPTARG
				;;
			p)
				proc=$OPTARG
				;;
			s)
				cgroupfs_prefix=$OPTARG
				;;
			v)
				verbose=1
				;;
			\?)
				echo "Invalid option: -${OPTARG}" >&2
				return 2
				;;
			:)
				echo "Option -${OPTARG} requires an argument" >&2
				return 2
				;;
		esac
	done
	# clear processed arguments
	shift $((OPTIND-1))
	
	if [[ -z "$maximum" ]]; then
		maximum=$(set -o pipefail; free -b | awk 'NR == 2 { print $4 }') || {
			echo "Could not determine maximum RAM from 'free'" >&2
			return 2
		}
	fi
	
	local controller=memory
	
	local procfs_cgroup_entry
	procfs_cgroup_entry=$(cgroup_util_find_controller_from_procfs_cgroup "$controller" < "${proc}/self/cgroup") || {
		[[ $verbose ]] && echo "Could not find cgroup controller '${controller}' in '${proc}/self/cgroup'" >&2
		return 3
	}
	
	local controller_version
	controller_version=$(echo "$procfs_cgroup_entry" | cgroup_util_get_controller_version_from_procfs_cgroup_line) || {
		[[ $verbose ]] && echo "Could not determine version for cgroup controller '${controller}' from '${proc}/self/cgroup'" >&2
		return 4
	}
	
	local controller_path
	controller_path=$(echo "$procfs_cgroup_entry" | cgroup_util_get_controller_path_from_procfs_cgroup_line) || {
		[[ $verbose ]] && echo "Could not determine path for cgroup controller '${controller}' from '${proc}/self/cgroup'" >&2
		return 5
	}
	
	local controller_mount
	controller_mount=$(cgroup_util_find_v"$controller_version"_mount_from_procfs_mountinfo "$controller" < "${proc}/self/mountinfo") || {
		[[ $verbose ]] && echo "Could not determine mount point for cgroup controller '${controller}' from '${proc}/self/mountinfo'" >&2
		return 6
	}
	# for testing purposes, a prefix can be passed to "relocate" the /sys/fs/cgroup/... location we are reading from next
	controller_mount="${cgroupfs_prefix}${controller_mount}"
	
	local location
	location=$(cgroup_util_find_v"$controller_version"_path "$controller" "$controller_mount" "$controller_path") || {
		[[ $verbose ]] && echo "Could not find a location for cgroup controller '${controller}'" >&2
		return 7
	}
	
	[[ $verbose ]] && echo "Reading cgroup v${controller_version} limit from '${location}'" >&2
	
	local limit
	case "$controller_version" in
		1)
			limit=$(cgroup_util_read_cgroupv1_memory_limit ${verbose:+"-v"} "$location") || return
			;;
		2)
			limit=$(cgroup_util_read_cgroupv2_memory_limit ${verbose:+"-v"} ${l:+"-L"} "$location") || return
			;;
		*)
			echo "Internal error: invalid cgroup controller version '${controller_version}'" >&2
			return 1
			;;
	esac
	
	if (( maximum > 0 && limit <= maximum )); then
		echo "$limit"
		return
	else
		[[ $verbose ]] && echo "Ignoring cgroup memory limit of ${limit} Bytes (exceeds maximum of ${maximum} Bytes)" >&2
		return 99
	fi
}
