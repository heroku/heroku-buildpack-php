#!/usr/bin/env bash

# a file to write captured warnings to
# it cannot be a variable, because the warnings function may be used in a pipeline, which causes a subshell, which can't modify parent scope variables
_captured_warnings_file=$(mktemp)
trap 'rm "$_captured_warnings_file"' EXIT

# Get config from caller's args ("$@") and set results into return variables.
# The following flags and options can be given:
#   -n (to avoid indenting the first line)
#   -r (to right-justify the computed prefix, i.e. pad with spaces on left)
#   -i INDENTWIDTH (e.g. 7, defaults to 7)
#   -p PREFIXSTRING (e.g. " !", defaults to "")
# It populates the following variables, if non-empty at call time:
#   - OPTIND (for re-setting "$@" using 'shift' in the caller, to get rid of parsed flags/options)
# The following flags and options can be used to pass the name of a return variable:
#   -N (will be set to '-n' if -n was present)
#   -R (will be set to '-R' if -r was present)
#   -I (the indent width as given in the -i argument, or the default)
#   -P (the computed prefix: PREFIXSTRING left-/right-padded to INDENT width)
# To call from another function, declare OPTIND as local, and pass "$@";
# provide any desired return variable names using the uppercase options, e.g.:
#   > local OPTIND=1 prefix
#   > get_message_config -P prefix "$@"
#   > shift ((OPTIND-1-2)) # remove two fewer args from "$@" due to -P
#   > echo "prefix is: '${prefix}'" # "prefix is: '       '"
# As shown, 'shift' is used in the calling function to re-set the argument index.
# The value of OPTIND must be reduced by 1 as with normal getopts use, and for
# any argument (option or option value) passed before "$@", the index must also
# be reduced by 1 - in the example above, that means OPTIND-1-2 due to '-P' and 'prefix'.
# The caller of that function can then still e.g. pass an indent: 'mywarning -i3 ...'.
# Options can be provided multiple times, and the last value read is used, which
# makes it possible to pass default values for options that the caller of the
# calling function can still override, e.g. 'mywarning -p " !" ...':
#   > local OPTIND=1 prefix
#   > get_message_config -p " !" -P prefix "$@"
#   > shift ((OPTIND-1-4)) # four fewer args to shift due to -p and -P above
#   > echo "prefix is: '${prefix}'" # "prefix is: ' !     '"
get_message_config() {
	local ljust="-l" # really just a dummy for later, any value works
	# arg values - these are populated from getopts below
	local indent_arg=7
	local no_first_line_indent_arg
	local prefix_arg
	local rjust_arg
	# what follows are return variables (if their names are passed to us, see above)
	# we use declare instead of local just for semantic distintion
	# double underscore prefixes to avoid collisions with outside variables
	# (these can still happen despite namerefs, e.g. with declare -n prefix=prefix)
	declare __indent_ret
	declare __no_first_line_indent_ret
	declare __prefix_ret
	declare __rjust_ret
	# (re-)set the value to what it needs to be for the next getopts call
	OPTIND=1 # explicitly not local so it "leaks" to the caller, where it's needed
	local opt
	while getopts ":i:I:p:P:nN:rR:" opt; do
		case $opt in
			i)
				if [[ $OPTARG != +([0-9]) ]]; then
					echo "Option -$opt requires a numeric value" >&2
					return 2
				fi
				indent_arg=$OPTARG
				;;
			I)
				if [[ -R __indent_ret ]]; then
					# already a nameref, so caller's caller passed this opt, too; reject
					echo "Cannot pass '-${opt}' multiple times" >&2
					return 2
				fi
				# re-declare output variable as a nameref
				declare -n __indent_ret="$OPTARG"
				;;
			n)
				# we just want "-n" back in there
				no_first_line_indent_arg="-${opt}"
				;;
			N)
				if [[ -R __no_first_line_indent_ret ]]; then
					# already a nameref, so caller's caller passed this opt, too; reject
					echo "Cannot pass '-${opt}' multiple times" >&2
					return 2
				fi
				# re-declare output variable as a nameref
				declare -n __no_first_line_indent_ret="$OPTARG"
				;;
			p)
				prefix_arg=$OPTARG
				;;
			P)
				if [[ -R __prefix_ret ]]; then
					# already a nameref, so caller's caller passed this opt, too; reject
					echo "Cannot pass '-${opt}' multiple times" >&2
					return 2
				fi
				# re-declare output variable as a nameref
				declare -n __prefix_ret="$OPTARG"
				;;
			r)
				# we just want "-r" back in there
				rjust_arg="-${opt}"
				ljust="" # for "+" parameter expansion later
				;;
			R)
				if [[ -R __rjust_ret ]]; then
					# already a nameref, so caller's caller passed this opt, too; reject
					echo "Cannot pass '-${opt}' multiple times" >&2
					return 2
				fi
				# re-declare output variable as a nameref
				declare -n __rjust_ret="$OPTARG"
				;;
			\?)
				echo "Invalid option: -$OPTARG" >&2
				return 2
				;;
			:)
				echo "Option -$OPTARG requires an argument" >&2
				return 2
				;;
		esac
	done
	__indent_ret=$indent_arg
	__no_first_line_indent_ret=$no_first_line_indent_arg
	# finally, assign the computed prefix
	# this also has to be a "return variable", because echo would require $() by the caller
	# that resulting subshell then would prevent reading the other variables above
	printf -v __prefix_ret "%${ljust:+"-"}${indent_arg}s" "${prefix_arg-""}"
	__rjust_ret=$rjust_arg
}

# indent width can be changed from default 7 using -i
# prefix can be changed from default " !" using -p
error() {
	local OPTIND=1 prefix
	get_message_config -p " !" -P prefix "$@"
	shift $((OPTIND-1-4)) # four fewer args to shift since we hand-passed -p/-P above
	# send all of our output to stderr
	exec 1>&2
	# if arguments are given, redirect them to stdin
	# this allows the function to be invoked with a string argument, or with stdin, e.g. via <<-EOF
	(( $# )) && exec <<< "$@"
	local color=$'\e[1;31m'
	prefix="${color}${prefix}" # bold and red
	echo "" | indent -p "$prefix"
	echo -n "ERROR: " | indent -p "$prefix"
	echo -n "$color" # turn color on again for rest of line (auto-disabled at end of every line by indent function)
	# this will be fed from stdin
	indent -n -p "$prefix"
	if [[ -s "$_captured_warnings_file" ]]; then
		echo "" | indent -p "$prefix"
		echo $'\e[1;33mREMINDER:\e[1;31m the following \e[1;33mwarnings\e[1;31m were emitted during the build;' | indent -p "$prefix"
		echo "check the details above, as they may be related to this error:" | indent -p "$prefix"
		indent < "$_captured_warnings_file" -p "${prefix}- "$'\e[1;33m' # print warning messages in yellow
	fi
	echo "" | indent -p "$prefix"
	exit 1
}

# indent width can be changed from default 7 using -i
# prefix can be changed from default " !" using -p
warning() {
	local OPTIND=1 prefix
	get_message_config -p " !" -P prefix "$@"
	shift $((OPTIND-5)) # four fewer args to shift since we passed -p above
	# send all of our output to stderr
	exec 1>&2
	# if arguments are given, redirect them to stdin
	# this allows the function to be invoked with a string argument, or with stdin, e.g. via <<-EOF
	(( $# )) && exec <<< "$@"
	local color=$'\e[1;33m' # bold and yellow
	prefix="${color}${prefix}"
	echo "" | indent -p "$prefix"
	echo -n "WARNING: " | indent -p "$prefix"
	echo -n "$color" # turn color on again for rest of line (auto-disabled at end of every line by indent function)
	# indent will be fed from stdin
	# we tee to FD 5, which is linked to STDOUT, and capture the real stdout into the warnings array
	# we must cat in the process substitution to read the remaining lines, because head only reads one line, and then the pipe would close, leading tee to fail
	indent -n -p "$prefix" | tee >(head -n1 >> "$_captured_warnings_file"; cat > /dev/null)
	echo "" | indent -p "$prefix"
}

# indent width can be changed from default 7 using -i
# prefix can be changed from default " !" using -p
warning_inline() {
	local OPTIND=1 prefix
	get_message_config -p " !" -P prefix "$@"
	shift $((OPTIND-1-4)) # four fewer args to shift since we passed -p/-P above
	# send all of our output to stderr
	exec 1>&2
	# if arguments are given, redirect them to stdin
	# this allows the function to be invoked with a string argument, or with stdin, e.g. via <<-EOF
	(( $# )) && exec <<< "$@"
	local color=$'\e[1;33m' # bold and yellow
	prefix="${color}${prefix}"
	echo -n "WARNING: " | indent -p "$prefix"
	echo -n "$color" # turn color on again for rest of line (auto-disabled at end of every line by indent function)
	# indent will be fed from stdin
	# we tee to FD 5, which is linked to STDOUT, and capture the real stdout into the warnings array
	# we must cat in the process substitution to read the remaining lines, because head only reads one line, and then the pipe would close, leading tee to fail
	indent -n -p "$prefix" | tee >(head -n1 >> "$_captured_warnings_file"; cat > /dev/null)
}

# indent width can be changed from default 7 using -i
status() {
	local OPTIND=1 indent
	get_message_config -I indent "$@"
	shift $((OPTIND-1-2)) # since we passed -I
	# send all of our output to stderr
	exec 1>&2
	# if arguments are given, redirect them to stdin
	# this allows the function to be invoked with a string argument, or with stdin, e.g. via <<-EOF
	(( $# )) && exec <<< "$@"
	local arrow="-> " # first character gets repeated below
	# print $indent-2 zeroes, which get replaced with dashes, followed by "> "
	printf "%0*d${arrow:1}" $((indent-2)) | tr 0 "${arrow:0:1}"
	# any remaining lines only get "> " as a right-justified prefix
	# this will be fed from stdin
	indent -n -r -i "$indent" -p "${arrow:1}"
}

# indent width can be changed from default 7 using -i
# prefix can be changed from default "" using -p
notice() {
	local OPTIND=1 prefix # visible to get_message_config, which will set "return" values
	get_message_config -P prefix "$@"
	shift $((OPTIND-1-2)) # since we passed -P
	# send all of our output to stderr
	exec 1>&2
	# if arguments are given, redirect them to stdin
	# this allows the function to be invoked with a string argument, or with stdin, e.g. via <<-EOF
	(( $# )) && exec <<< "$@"
	echo "" | indent -p "$prefix"
	echo -n $'\e[1;33mNOTICE: \e[0m' | indent -p "$prefix" # bold; yellow
	# this will be fed from stdin
	indent -n -p "$prefix"
	echo "" | indent -p "$prefix"
}

# indent width can be changed from default 7 using -i
# prefix can be changed from default "" using -p
notice_inline() {
	local OPTIND=1 prefix
	get_message_config -P prefix "$@"
	shift $((OPTIND-1-2))
	# send all of our output to stderr
	exec 1>&2
	# if arguments are given, redirect them to stdin
	# this allows the function to be invoked with a string argument, or with stdin, e.g. via <<-EOF
	(( $# )) && exec <<< "$@"
	echo -n $'\e[1;33mNOTICE: \e[0m' | indent -p "$prefix" # bold; yellow
	# this will be fed from stdin
	indent -n -p "$prefix"
}

# sed -l basically makes sed replace and buffer through stdin to stdout
# so you get updates while the command runs and dont wait for the end
# e.g. npm install | indent
# indent width can be changed from default 7 using -i
# prefix can be changed from default "" using -p
# pass -n to skip indentation of first line
indent() {
	local no_first_line_indent OPTIND=1 prefix
	get_message_config -N no_first_line_indent -P prefix "$@"
	shift $((OPTIND-1-4))
	# if we were given option -n, that indicates we shouldn't indent the first line
	# when that is set, we specify a range filter, starting at line 2, ending when regex "!^" matches, which is never (nothing can precede a ^)
	# option -p can be used to pass a prefix, we default to option -i (or 7 if not given) space characters
	# with -p, this can be set to e.g. " !     " to decorate each line of an error message
	local c="${no_first_line_indent:+"2,/!^/"} s/^/$prefix/"
	local r=$'s/$/\e[0m/' # end of line color/style reset
	local r=$'/\e\\[[[:digit:];]+m/s/$/\e[0m/' # end of line color/style reset if there are any color ANSI codes on the line (could be in prefix!)
	local s=$'s/(\e\\[[[:digit:];]+m)\\1+/\\1/'
	case $(uname) in
		Darwin) sed -l -E -e "$c" -e "$r" -e "$s";; # mac/bsd sed: -l buffers on line boundaries
		*)      sed -u -E -e "$c" -e "$r" -e "$s";; # unix/gnu sed: -u unbuffered (arbitrary) chunks of data
	esac
}

export_env_dir() {
	local env_dir=$1
	local whitelist_regex=${2:-''}
	local blacklist_regex=${3:-'^(PATH|GIT_DIR|CPATH|CPPATH|LD_PRELOAD|LIBRARY_PATH|IFS)$'}
	if [ -d "$env_dir" ]; then
		for e in $(ls $env_dir); do
			echo "$e" | grep -E "$whitelist_regex" | grep -qvE "$blacklist_regex" &&
			export "$e=$(cat $env_dir/$e)"
			:
		done
	fi
}

curl_retry_on_18() {
	local ec=18;
	local attempts=0;
	while (( ec == 18 && attempts++ < 3 )); do
		curl "$@" # -C - would return code 33 if unsupported by server
		ec=$?
		sleep "$attempts" # naive backoff
	done
	return $ec
}

err_trap() {
	local trace=$(
		local frame=0
		while caller "$frame"; do
			(( ++frame ));
		done
	)

	build_report::set_string failure_reason errexit
	build_report::set_string failure_detail "$trace"

	error <<-EOF
		An unknown internal error occurred.
	
		Contact Heroku Support for assistance if this problem persists.
		
		Stack trace follows for debugging purposes:
		${trace}
	EOF
}

exit_trap() {
	local exit_status=$?

	build_report::has_running_timers && {
		local open_timers
		mapfile -t open_timers < <(build_report::get_running_timer_names)
		build_report::set_string open_timers "$(IFS=","; echo "${open_timers[*]}")"
		build_report::stop_timers
	}

	# if exit status was 0, or if a failure_reason is already set, skip the rest
	(( exit_status )) || return
	build_report::has failure_reason && return

	local trace=$(
		local frame=0
		while caller "$frame"; do
			(( ++frame ));
		done
	)

	build_report::set_string failure_reason unknown
	build_report::set_string failure_detail "$trace"
}

# Logging
# -------

# These functions expect BPLOG_PREFIX and BUILDPACK_LOG_FILE to be defined (BUILDPACK_LOG_FILE can point to /dev/null if not provided by the buildpack).
# Example: BUILDPACK_LOG_FILE=${BUILDPACK_LOG_FILE:-/dev/null}; BPLOG_PREFIX="buildpack.go"

# Returns now, in milleseconds. Useful for logging.
# Example: $ let start=$(nowms); sleep 30; mtime "glide.install.time" "${start}"
nowms() {
	date +%s%3N
}

# Measures time elapsed for a specific build step.
# Usage: $ let start=$(nowms); mtime "glide.install.time" "${start}"
# https://github.com/heroku/engineering-docs/blob/master/guides/logs-as-data.md#distributions-measure
mtime() {
	local key="${BPLOG_PREFIX}.${1}"
	local start="${2}"
	local end="${3:-$(nowms)}"
	echo "${key} ${start} ${end}" | awk '{ printf "measure#%s=%.3f\n", $1, ($3 - $2)/1000 }' >> "${BUILDPACK_LOG_FILE}"
}

# Logs a count for a specific built step.
# Usage: $ mcount "tool.govendor"
# https://github.com/heroku/engineering-docs/blob/master/guides/logs-as-data.md#counting-count
mcount() {
	local k="${BPLOG_PREFIX}.${1}"
	local v="${2:-1}"
	echo "count#${k}=${v}" >> "${BUILDPACK_LOG_FILE}"
}

# Logs a measure for a specific build step.
# Usage: $ mmeasure "tool.installed_dependencies" 42
# https://github.com/heroku/engineering-docs/blob/master/guides/logs-as-data.md#distributions-measure
mmeasure() {
	local k="${BPLOG_PREFIX}.${1}"
	local v="${2}"
	echo "measure#${k}=${v}" >> "${BUILDPACK_LOG_FILE}"
}

# Logs a unuique measurement build step.
# Usage: $ munique "versions.count" 2.7.13
# https://github.com/heroku/engineering-docs/blob/master/guides/logs-as-data.md#uniques-unique
munique() {
	local k="${BPLOG_PREFIX}.${1}"
	local v="${2}"
	echo "unique#${k}=${v}" >> "${BUILDPACK_LOG_FILE}"
}
