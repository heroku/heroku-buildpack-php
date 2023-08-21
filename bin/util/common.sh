# a file to write captured warnings to
# it cannot be a variable, because the warnings function may be used in a pipeline, which causes a subshell, which can't modify parent scope variables
_captured_warnings_file=$(mktemp -t heroku-buildpack-php-captured-warnings-XXXX)

error() {
	# send all of our output to stderr
	exec 1>&2
	# if arguments are given, redirect them to stdin
	# this allows the funtion to be invoked with a string argument, or with stdin, e.g. via <<-EOF
	(( $# )) && exec <<< "$@"
	echo -e "\033[1;31m" # bold; red
	echo -n " !     ERROR: "
	# this will be fed from stdin
	indent no_first_line_indent " !     "
	if [[ -s "$_captured_warnings_file" ]]; then
		echo "" | indent "" " !     "
		echo -e "\033[1;33mREMINDER:\033[1;31m the following \033[1;33mwarnings\033[1;31m were emitted during the build;" | indent "" " !     "
		echo "check the details above, as they may be related to this error:" | indent "" " !     "
		cat "$_captured_warnings_file" | indent "" "$(echo -e " !     \033[1;33m-\033[1;31m ")"
	fi
	echo -e "\033[0m" # reset style
	exit 1
}

warning() {
	# send all of our output to stderr
	exec 1>&2
	# if arguments are given, redirect them to stdin
	# this allows the funtion to be invoked with a string argument, or with stdin, e.g. via <<-EOF
	(( $# )) && exec <<< "$@"
	echo -e "\033[1;33m" # bold; yellow
	echo -n " !     WARNING: "
	# indent will be fed from stdin
	# we tee to FD 5, which is linked to STDOUT, and capture the real stdout into the warnings array
	# we must cat in the process substitution to read the remaining lines, because head only reads one line, and then the pipe would close, leading tee to fail
	indent no_first_line_indent " !     " | tee >(head -n1 >> "$_captured_warnings_file"; cat > /dev/null)
	echo -e "\033[0m" # reset style
}

warning_inline() {
	# send all of our output to stderr
	exec 1>&2
	# if arguments are given, redirect them to stdin
	# this allows the funtion to be invoked with a string argument, or with stdin, e.g. via <<-EOF
	(( $# )) && exec <<< "$@"
	echo -n -e "\033[1;33m" # bold; yellow
	echo -n " !     WARNING: "
	# indent will be fed from stdin
	# we tee to FD 5, which is linked to STDOUT, and capture the real stdout into the warnings array
	# we must cat in the process substitution to read the remaining lines, because head only reads one line, and then the pipe would close, leading tee to fail
	indent no_first_line_indent " !     " | tee >(head -n1 >> "$_captured_warnings_file"; cat > /dev/null)
	echo -n -e "\033[0m" # reset style
}

status() {
	# send all of our output to stderr
	exec 1>&2
	# if arguments are given, redirect them to stdin
	# this allows the funtion to be invoked with a string argument, or with stdin, e.g. via <<-EOF
	(( $# )) && exec <<< "$@"
	echo -n "-----> "
	# this will be fed from stdin
	cat
}

notice() {
	# send all of our output to stderr
	exec 1>&2
	# if arguments are given, redirect them to stdin
	# this allows the funtion to be invoked with a string argument, or with stdin, e.g. via <<-EOF
	(( $# )) && exec <<< "$@"
	echo
	echo -n -e "\033[1;33m" # bold; yellow
	echo -n "       NOTICE: "
	echo -n -e "\033[0m" # reset style
	# this will be fed from stdin
	indent no_first_line_indent
	echo
}

notice_inline() {
	# send all of our output to stderr
	exec 1>&2
	# if arguments are given, redirect them to stdin
	# this allows the funtion to be invoked with a string argument, or with stdin, e.g. via <<-EOF
	(( $# )) && exec <<< "$@"
	echo -n -e "\033[1;33m" # bold; yellow
	echo -n "       NOTICE: "
	echo -n -e "\033[0m" # reset style
	# this will be fed from stdin
	indent no_first_line_indent
}

# sed -l basically makes sed replace and buffer through stdin to stdout
# so you get updates while the command runs and dont wait for the end
# e.g. npm install | indent
indent() {
	# if any value (e.g. a non-empty string, or true, or false) is given for the first argument, this will act as a flag indicating we shouldn't indent the first line; we use :+ to tell SED accordingly if that parameter is set, otherwise null string for no range selector prefix (it selects from line 2 onwards and then every 1st line, meaning all lines)
	# if the first argument is an empty string, it's the same as no argument (useful if a second argument is passed)
	# the second argument is the prefix to use for indenting; defaults to seven space characters, but can be set to e.g. " !     " to decorate each line of an error message
	local c="${1:+"2,999"} s/^/${2-"       "}/"
	case $(uname) in
		Darwin) sed -l "$c";; # mac/bsd sed: -l buffers on line boundaries
		*)      sed -u "$c";; # unix/gnu sed: -u unbuffered (arbitrary) chunks of data
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
