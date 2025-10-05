#!/usr/bin/env bash

BUILD_DATA_FILE="${cache_dir:?}/build-data/php.json"

# Initializes the build data store, overwriting the file from the previous build if it exists.
# Call this at the start of `bin/compile` before using any other functions from this file.
#
# Usage:
# ```
# build_report::setup
# ```
function build_report::setup() {
	mkdir -p "$(dirname "${BUILD_DATA_FILE}")"
	echo "{}" >"${BUILD_DATA_FILE}"
	# just a simple check, sometimes there are broken old versions from unmaintained buildpacks
	if ! jq --version >/dev/null; then
		echo >&2 "ERROR: 'jq' not found or incompatible."
		echo >&2 "Ensure you aren't running outdated buildpacks or overriding PATH."
		echo >&2 "For reference, the lookup result for command 'jq' follows:"
		type -a jq # writes success list and failure message to stderr
		return 1
	fi
}

# Gets a value from the build data store. This value will be encoded as valid JSON and terminated with a newline.
# Exit status is 5 if the key was not found.
#
# Usage:
# ```
# build_report::get "some_key"
# ```
function build_report::get() {
	JQ_EXTRA_OPTS= build_report::_get "$1"
}

# Gets a value from the build data store. This value will be printed "raw" and not terminated with a newline.
# Exit status is 5 if the key was not found.
#
# Usage:
# ```
# build_report::get "some_key"
# ```
function build_report::get_raw() {
	JQ_EXTRA_OPTS=j build_report::_get "$1"
}

# Internal helper to fetch a value from the build data store.
# Exit status is 5 if the key was not found.
# Pass env var JQ_EXTRA_OPTS to supply additional jq options such as "j" for raw output.
# 
# Usage:
# ```
# JQ_EXTRA_OPTS= build_report::_get "some_key"
# JQ_EXTRA_OPTS=j build_report::_get "some_key"
# ```
function build_report::_get() {
	jq -cM"${JQ_EXTRA_OPTS-}" --arg key "$1" 'if(has($key)) then .[$key] else "" | halt_error end' "${BUILD_DATA_FILE}"
}

# Checks whether a key is set in the build data store.
# Exit status is 5 if the key was not found.
#
# Usage:
# ```
# build_report::has "some_key"
# ```
function build_report::has() {
	build_report::_get "$1" > /dev/null
}


# Sets a string build data value. The value will be wrapped in double quotes and escaped for JSON.
#
# Usage:
# ```
# build_report::set_string "python_version" "1.2.3"
# build_report::set_string "failure_reason" "install-dependencies::pip"
# ```
function build_report::set_string() {
	local key="${1}"
	local value="${2}"
	build_report::_set "${key}" "${value}" "true"
}

# Sets a build data value as raw JSON data. The value parameter must be valid JSON value, that's also
# a supported Honeycomb data type (string, integer, float, or boolean only; no arrays or objects).
# For strings, use `build_report::set_string` instead since it will handle the escaping/quoting for you.
# And for durations, use `build_report::set_duration`.
#
# Usage:
# ```
# build_report::set_raw "python_version_outdated" "true"
# build_report::set_raw "foo_size_mb" "42.5"
# ```
function build_report::set_raw() {
	local key="${1}"
	local value="${2}"
	build_report::_set "${key}" "${value}" "false"
}

# Internal helper to write a key/value pair to the build data store. The buildpack shouldn't call this directly.
# Takes a key, value, and a boolean flag indicating whether the value needs to be quoted.
#
# Usage:
# ```
# build_report::_set "foo_string" "quote me" "true"
# build_report::_set "bar_number" "99" "false"
# ```
function build_report::_set() {
	local key="${1}"
	# Truncate the value to an arbitrary 200 characters since it will sometimes contain user-provided
	# inputs which may be unbounded in size. Ideally individual call sites will perform more aggressive
	# truncation themselves based on the expected value size, however this is here as a fallback.
	# (Honeycomb supports string fields up to 64KB in size, however, it's not worth filling up the
	# build data store or bloating the payload passed back to Vacuole/submitted to Honeycomb given the
	# extra content in those cases is not normally useful.)
	local value="${2:0:200}"
	local needs_quoting="${3}"

	if [[ "${needs_quoting}" == "true" ]]; then
		# Values passed using `--arg` are treated as strings, and so have double quotes added and any JSON
		# special characters (such as newlines, carriage returns, double quotes, backslashes) are escaped.
		local jq_args=(--arg value "${value}")
	else
		# Values passed using `--argjson` are treated as raw JSON values, and so aren't escaped or quoted.
		local jq_args=(--argjson value "${value}")
	fi

	local new_data_file_contents
	new_data_file_contents="$(jq --arg key "${key}" "${jq_args[@]}" '. + { ($key): ($value) }' "${BUILD_DATA_FILE}")"
	echo "${new_data_file_contents}" >"${BUILD_DATA_FILE}"
}

# Returns the current time since the UNIX Epoch, as a float with microseconds precision.
# Internal helper used by build_report::start_timer / build_report::get_timer.
#
# Usage:
# ```
# build_report::_current_unix_realtime
# ```
function build_report::_current_unix_realtime() {
	# We use a subshell with `LC_ALL=C` to ensure the output format isn't affected by system locale.
	(
		LC_ALL=C
		echo "${EPOCHREALTIME}"
	)
}

# Starts a named timer.
# Will later be logged as "$name.duration", unless $name is "__main__";
# in that case, the logged key will be just "duration".
#
# Usage:
# ```
# build_report::start_timer "my_timer_name"
# ```
function build_report::start_timer() {
	declare -gA __build_report_start_times
	__build_report_start_times["${1}"]=$(build_report::_current_unix_realtime)
}

# Gets the current elapsed time (in seconds) for a named timer.
# Return value is a floating-point numeric string.
# Exit status is 1 if the given timer does not exist.
#
# Usage:
# ```
# build_report::get_timer "my_timer_name"
# ```
function build_report::get_timer() {
	declare -gA __build_report_start_times
	local key="${1}"
	if [[ -v __build_report_start_times["${key}"] ]]; then
		local start_time="${__build_report_start_times["${key}"]}"
		local end_time="$(build_report::_current_unix_realtime)"
		awk -v start="${start_time}" -v end="${end_time}" 'BEGIN { printf "%f", (end - start) }'
	else
		echo "No such timer: ${key}" >&2
		return 1
	fi
}

# Clears a named timer.
#
# Usage:
# ```
# build_report::clear_timer "my_timer_name"
# ```
function build_report::clear_timer() {
	declare -gA __build_report_start_times
	unset __build_report_start_times["${key}"]
}

# Clears all timers.
#
# Usage:
# ```
# build_report::clear_timers
# ```
function build_report::clear_timers() {
	declare -gA __build_report_start_times=()
}

# Stops and logs a named timer.
# Will be logged as "$name.duration", unless $name is "__main__";
# in that case, the logged key will be just "duration".
# Exit status is 1 if the given timer does not exist.
#
# Usage:
# ```
# build_report::stop_timer "my_timer_name"
# ```
function build_report::stop_timer() {
	local key="${1}"
	local duration
	duration=$(build_report::get_timer "${key}") && {
		local key_to_log
		if [[ "${key}" == "__main__" ]]; then
			key_to_log="duration"
		else
			key_to_log="${key}.duration"
		fi
		build_report::set_raw "${key_to_log}" "${duration}"
		build_report::clear_timer "${key}"
	} || {
		return 1
	}
}

# Stops and logs all timers.
#
# Usage:
# ```
# build_report::stop_timers
# ```
function build_report::stop_timers() {
	declare -gA __build_report_start_times
	local key
	for key in "${!__build_report_start_times[@]}"; do
		build_report::stop_timer "${key}"
	done
}

# Checks whether any timers are still running.
# Exit status is 0 if there are timers, 1 otherwise.
#
# Usage:
# ```
# build_report::has_running_timers
# ```
function build_report::has_running_timers() {
	declare -gA __build_report_start_times
	(( ${#__build_report_start_times[@]} )) && return 0 || return 1
}

# Gets a list of names of all running timers, sorted by start time.
# Return value is a newline separated list of names.
#
# Usage:
# ```
# build_report::get_running_timer_names "my_timer_name"
# ```
function build_report::get_running_timer_names() {
	declare -gA __build_report_start_times
	local key
	for key in "${!__build_report_start_times[@]}"; do
		printf "%s\t%s\n" "${key}" "${__build_report_start_times[$key]}"
	done | LC_ALL=C sort -n -t $'\t' -k2 | cut -d $'\t' -f1
}

# Prints the contents of the build data store in sorted JSON format.
#
# Usage:
# ```
# build_report::print_bin_report_json
# ```
function build_report::print_bin_report_json() {
	jq --sort-keys '.' "${BUILD_DATA_FILE}"
}
