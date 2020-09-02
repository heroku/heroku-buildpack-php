#!/usr/bin/env bash

# fail harder
set -u

if ! type -p "timeout" > /dev/null; then
	echo "This program requires 'timeout'." >&2
	exit 1
fi

print_help() {
	cat >&2 <<-EOF
		
		${1:-Execute a given program and terminate after timeout or line match.}
		
		Usage:
		  waitforit [options] <DURATION> <TEXT_TO_MATCH> <COMMAND...>
		
		The given COMMAND will be terminated after the given number of seconds, or the
		given TEXT_TO_MATCH has matched, whichever comes first.
		
		The exit status of 'waitforit' will be the exit status of 'timeout' if the
		given TEXT_TO_MATCH did not match, or 0 otherwise.
		
		DURATION is a floating point number with an optional suffix:
		's' for seconds (the default), 'm' for minutes, 'h' for hours or 'd' for days.
		It can also be a string of 'timeout' options and duration; the argument is
		passed to 'timeout' unquoted.
		
		TEXT_TO_MATCH is a 'grep -E' expression.
		
		One particularly useful aspect of this program is that if stdout is a pipe,
		the program behaves so that it writes the matched text to stdout, and will
		then wait for the receiving end of the pipe to close before terminating the
		program. This can be used to perform another operation once the given text has
		matched, e.g.:
		
		waitforit 15 "ready for connections" start-web-server.sh | \
			{ read && curl http://localhost:8080/test | grep "hello world"; }
		
		The 'read' statement waits for the matched text to occur and thus blocks the
		execution of the curl/grep test operation until the server has started. It is
		important to chain the commands following 'read' using '&&', as 'read' will
		have a non-zero exit status if the 'waitforit' invocation timed out or did
		not match the desired string.
	EOF
}

if [[ "$#" -lt "3" ]]; then
	print_help
	exit 2
fi

duration=$1; shift
text=$1; shift

pipeout=
# check if stdout is a pipeline, in which case we'll behave differently
[[ -p /dev/stdout ]] && pipeout=1

if [[ $pipeout ]]; then
	grepargs="-m1"
else
	grepargs="-q"
fi

# this handler will fire if a program reading from us (to kick off e.g. a test) exits
# in that event, we want the child process to terminate
# trap 'trap - PIPE; echo "SIGPIPE received, shutting down..." >&2; cleanup TERM; kill -PIPE $$' PIPE

# TODO: have option to suppress output to stderr
teedest="/dev/stderr"
(
	# trap 'echo "finished" >&3;' EXIT

	trap 'trap - PIPE; kill -TERM $pid 2> /dev/null || true; wait $pid; exit 0' PIPE

	# we redirect stderr to stdout so it can be captured as well...
	# ... and redirect stdout to a tee that also writes to stderr (so the output is visible) - this is done so that $! is still the pid of the timeout command
	timeout $duration "$@" > >(tee "$teedest") 2>&1 & pid=$!
	
	while kill -0 $pid 2>/dev/null; do echo "." 2>/dev/null; sleep 0.1; done;
	
	wait $pid || exit $?
	
	exec 1>&-;
) | { grep --line-buffered $grepargs -E -e "$text" && while test $pipeout; do echo "." 2>/dev/null; sleep 0.1; done; exec 1>&-; }

exit ${PIPESTATUS[0]}
