# a file to write captured warnings to
# it cannot be a variable, because the warnings function may be used in a pipeline, which causes a subshell, which can't modify parent scope variables
_captured_warnings_file=$(mktemp -t heroku-buildpack-php-captured-warnings-XXXX)

# Get config from caller's args ("$@") and set results into return variables.
# The following flags and options can be given:
# --no-first-line-indent
# --rjust (to right-justify the computed prefix, i.e. pad with spaces on left)
# -p PREFIXSTRING (e.g. " !", defaults to "")
# -i INDENTWIDTH (e.g. 7, defaults to 7)
# It populates the following variables, if non-empty at call time:
# - OPTIND (for re-setting "$@" using 'shift')
# - no_first_line_indent (set to '--no-first-line-indent' if present)
# - rjust (set to '--rjust' if present)
# - indent (the indent width as given in the -i argument)
# - prefix (the computed prefix: PREFIXSTRING left-/right-padded to INDENT width)
# To call from another function, pass "$@" and declare at least OPTIND and
# any of the other return variables beforehand as not null, and any non-desired
# return variables as null, e.g.:
# > local OPTIND=1 prefix=""
# > local indent no_first_line_indent rjust # prevent outside scope interference
# > get_message_config "$@"
# > shift ((OPTIND-1))
# > echo "prefix is: '${prefix}'" # "prefix is: '       '"
# The user of that function can then still e.g. pass an indent: 'mywarning -i3 ...'
# It is possible to pass e.g. a default value for the prefix that the user of
# the calling function can still override, e.g. 'mywarning -p " !" ...':
# > local OPTIND=1 prefix="" # visible to get_message_config, which will set "return" values
# > local indent no_first_line_indent rjust # prevent outside scope interference
# > get_message_config -p " !" "$@"
# > shift ((OPTIND-1-2)) # two fewer args to shift due to -p above
# > echo "prefix is: '${prefix}'" # "prefix is: ' !     '"
get_message_config() {
	local optstring=":-:i:p:"
	local prefix_arg
	local ljust="--ljust" # really just a dummy for later, any value works
	if [[ -z "${OPTIND+isset}" ]]; then
		local OPTIND # caller does not have it set, do not leak it outside
	fi
	OPTIND=1 # (re-)set the value to what it needs to be for the next getopts call
	if [[ -z "${rjust+isset}" ]]; then
		local rjust # caller does not have it set, do not leak it outside
	fi
	if [[ -z "${indent+isset}" ]]; then
		local indent # caller does not have it set, do not leak it outside
	fi
	indent=7 # (re-)set to our default value
	# process flags first
	while getopts "$optstring" opt; do
		case $opt in
			-)
				case "$OPTARG" in
					no-first-line-indent)
						if [[ "${no_first_line_indent+isset}" == "isset" ]]; then
							no_first_line_indent="--${OPTARG}" # available in the caller
						fi
						;;
					rjust)
						rjust="--${OPTARG}" # available in the caller
						ljust="" # for "+" parameter expansion later
						;;
					*)
						echo "Invalid option: --$OPTARG" >&2
						return 2
						;;
				esac
				;;
		esac
	done
	OPTIND=1 # start over with options parsing
	while getopts "$optstring" opt; do
		case $opt in
			i)
				if [[ $OPTARG != +([0-9]) ]]; then
					echo "Option -$opt requires a numeric value" >&2
					return 2
				fi
				indent=$OPTARG
				;;
			p)
				prefix_arg="$OPTARG"
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
	if [[ -z "${prefix+isset}" ]]; then
		# caller does not have this set, do not leak it outside
		# we did not bail out earlier in case they wanted to know just the indent
		return
	fi
	# finally, assign the computed prefix
	# this also has to be a "return variable", because echo would require $() by the caller
	# that resulting subshell then would prevent reading the other variables above
	printf -v prefix "%${ljust:+"-"}${indent}s" "${prefix_arg-""}"
}

# indent width can be changed from default 7 using -i
# prefix can be changed from default " !" using -p
error() {
	local OPTIND=1 prefix="" # visible to get_message_config, which will set "return" values
	local indent no_first_line_indent rjust # prevent outside scope interference
	get_message_config -p " !" "$@"
	shift $((OPTIND-1-2)) # two fewer args to shift since we passed -p above
	# send all of our output to stderr
	exec 1>&2
	# if arguments are given, redirect them to stdin
	# this allows the funtion to be invoked with a string argument, or with stdin, e.g. via <<-EOF
	(( $# )) && exec <<< "$@"
	local color=$'\033[1;31m'
	prefix="${color}${prefix}" # bold and red
	echo "" | indent -p "$prefix"
	echo -n "ERROR: " | indent -p "$prefix"
	echo -n "$color" # turn color on again for rest of line (auto-disabled at end of every line by indent function)
	# this will be fed from stdin
	indent --no-first-line-indent -p "$prefix"
	if [[ -s "$_captured_warnings_file" ]]; then
		echo "" | indent -p "$prefix"
		echo -e "\033[1;33mREMINDER:\033[1;31m the following \033[1;33mwarnings\033[1;31m were emitted during the build;" | indent -p "$prefix"
		echo "check the details above, as they may be related to this error:" | indent -p "$prefix"
		cat "$_captured_warnings_file" | indent -p "${prefix}- "$'\033[1;33m' # print warning messages in yellow
	fi
	echo "" | indent -p "$prefix"
	exit 1
}

# indent width can be changed from default 7 using -i
# prefix can be changed from default " !" using -p
warning() {
	local OPTIND=1 prefix="" # visible to get_message_config, which will set "return" values
	local indent no_first_line_indent rjust # prevent outside scope interference
	get_message_config -p " !" "$@"
	shift $((OPTIND-1-2)) # two fewer args to shift since we passed -p above
	# send all of our output to stderr
	exec 1>&2
	# if arguments are given, redirect them to stdin
	# this allows the funtion to be invoked with a string argument, or with stdin, e.g. via <<-EOF
	(( $# )) && exec <<< "$@"
	local color=$'\033[1;33m' # bold and yellow
	prefix="${color}${prefix}"
	echo "" | indent -p "$prefix"
	echo -n "WARNING: " | indent -p "$prefix"
	echo -n "$color" # turn color on again for rest of line (auto-disabled at end of every line by indent function)
	# indent will be fed from stdin
	# we tee to FD 5, which is linked to STDOUT, and capture the real stdout into the warnings array
	# we must cat in the process substitution to read the remaining lines, because head only reads one line, and then the pipe would close, leading tee to fail
	indent --no-first-line-indent -p "$prefix" | tee >(head -n1 >> "$_captured_warnings_file"; cat > /dev/null)
	echo "" | indent -p "$prefix"
}

# indent width can be changed from default 7 using -i
# prefix can be changed from default " !" using -p
warning_inline() {
	local OPTIND=1 prefix="" # visible to get_message_config, which will set "return" values
	local indent no_first_line_indent rjust # prevent outside scope interference
	get_message_config -p " !" "$@"
	shift $((OPTIND-1-2)) # two fewer args to shift since we passed -p above
	# send all of our output to stderr
	exec 1>&2
	# if arguments are given, redirect them to stdin
	# this allows the funtion to be invoked with a string argument, or with stdin, e.g. via <<-EOF
	(( $# )) && exec <<< "$@"
	local color=$'\033[1;33m' # bold and yellow
	prefix="${color}${prefix}"
	echo -n "WARNING: " | indent -p "$prefix"
	echo -n "$color" # turn color on again for rest of line (auto-disabled at end of every line by indent function)
	# indent will be fed from stdin
	# we tee to FD 5, which is linked to STDOUT, and capture the real stdout into the warnings array
	# we must cat in the process substitution to read the remaining lines, because head only reads one line, and then the pipe would close, leading tee to fail
	indent --no-first-line-indent -p "$prefix" | tee >(head -n1 >> "$_captured_warnings_file"; cat > /dev/null)
}

# indent width can be changed from default 7 using -i
status() {
	local OPTIND=1 indent=0 # visible to get_message_config, which will set "return" values
	local no_first_line_indent prefix rjust # prevent outside scope interference
	get_message_config "$@"
	shift $((OPTIND-1))
	# send all of our output to stderr
	exec 1>&2
	# if arguments are given, redirect them to stdin
	# this allows the funtion to be invoked with a string argument, or with stdin, e.g. via <<-EOF
	(( $# )) && exec <<< "$@"
	local arrow="-> " # first character gets repeated below
	# print $indent-2 zeroes, which get replaced with dashes, followed by "> "
	printf "%0*d${arrow:1}" $((indent-2)) | tr 0 "${arrow:0:1}"
	# any remaining lines only get "> " as a right-justified prefix
	# this will be fed from stdin
	indent --no-first-line-indent --rjust -i "$indent" -p "${arrow:1}"
}

# indent width can be changed from default 7 using -i
# prefix can be changed from default "" using -p
notice() {
	local OPTIND=1 prefix="" # visible to get_message_config, which will set "return" values
	local indent no_first_line_indent rjust # prevent outside scope interference
	get_message_config "$@"
	shift $((OPTIND-1))
	# send all of our output to stderr
	exec 1>&2
	# if arguments are given, redirect them to stdin
	# this allows the funtion to be invoked with a string argument, or with stdin, e.g. via <<-EOF
	(( $# )) && exec <<< "$@"
	echo "" | indent -p "$prefix"
	echo -n -e "\033[1;33mNOTICE: \033[0m" | indent -p "$prefix" # bold; yellow
	# this will be fed from stdin
	indent --no-first-line-indent -p "$prefix"
	echo "" | indent -p "$prefix"
}

# indent width can be changed from default 7 using -i
# prefix can be changed from default "" using -p
notice_inline() {
	local OPTIND=1 prefix="" # visible to get_message_config, which will set "return" values
	local indent no_first_line_indent rjust # prevent outside scope interference
	get_message_config "$@"
	shift $((OPTIND-1))
	# send all of our output to stderr
	exec 1>&2
	# if arguments are given, redirect them to stdin
	# this allows the funtion to be invoked with a string argument, or with stdin, e.g. via <<-EOF
	(( $# )) && exec <<< "$@"
	echo -n -e "\033[1;33mNOTICE: \033[0m" | indent -p "$prefix" # bold; yellow
	# this will be fed from stdin
	indent --no-first-line-indent -p "$prefix"
}

# sed -l basically makes sed replace and buffer through stdin to stdout
# so you get updates while the command runs and dont wait for the end
# e.g. npm install | indent
# indent width can be changed from default 7 using -i
# prefix can be changed from default "" using -p
# pass --no-first-line-indent as a flag to skip indentation of first line
indent() {
	local no_first_line_indent="" OPTIND=1 prefix="" # visible to get_message_config, which will set "return" values
	local indent rjust # prevent outside scope interference
	get_message_config "$@"
	shift $((OPTIND-1))
	# if we were given a flag --no-first-line-indent, that indicates we shouldn't indent the first line
	# when that is set, we specify a range filter, starting at line 2, ending when regex "!^" matches, which is never (nothing can precede a ^)
	# option -p can be used to pass a prefix, we default to option -i (or 7 if not given) space characters
	# with -p, this can be set to e.g. " !     " to decorate each line of an error message
	local c="${no_first_line_indent:+"2,/!^/"} s/^/$prefix/"
	local r=$'s/$/\033[0m/' # end of line color/style reset
	case $(uname) in
		Darwin) sed -l -e "$c" -e "$r";; # mac/bsd sed: -l buffers on line boundaries
		*)      sed -u -e "$c" -e "$r";; # unix/gnu sed: -u unbuffered (arbitrary) chunks of data
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
	error <<-EOF
		An unknown internal error occurred.
	
		Contact Heroku Support for assistance if this problem persists.
		
		Stack trace follows for debugging purposes:
		$(
			local frame=0
			while caller $frame; do
				((frame++));
			done
		)
	EOF
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
