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
# check if stdout is a pipeline (we can't -p /dev/stdout, so a TTY check on FD 1 is the next closest thing), in which case we'll behave differently
[[ -t 1 ]] || pipeout=1

if [[ $pipeout ]]; then
	grepargs="-m1"
else
	grepargs="-q"
fi

# First, we spawn a subshell that executes the desired program, wrapped in timeout (as a hard limit to prevent hanging forever if the desired text does not match).
# A trap is set up that fires on SIGPIPE (and SIGUSR1, see note below) and kills the program.
# After the program is launched, we check if it's alive in a loop, and write a dot to the following pipeline
# This writing acts as a check to see whether the following pipeline is still alive - if it is not, that's because it has terminated (see its explanation further below).
# Once the pipeline is gone, our trap fires, and shuts down the program.

# TODO: have option to suppress output to stderr
(
	# we trap SIGPIPE, but also SIGUSR1
	# there are cases where the invoking shell does not allow SIGPIPE traps to be installed
	trap 'trap - PIPE USR1; kill -TERM $pid 2> /dev/null || true; wait $pid; exit 0' PIPE USR1

	# we redirect stderr to stdout so it can be captured as well...
	# ... and redirect stdout to a tee that also writes to stderr (so the output is visible) - this is done so that $! is still the pid of the timeout command
	timeout $duration "$@" > >(tee >(cat 1>&2)) 2>&1 & pid=$!
	
	# while the program is alive, write a dot to the following pipeline
	# once the following pipeline has finished, the echo will cause a SIGPIPE, which our trap above will catch
	# for cases where SIGPIPE handlers are not available, we manually issue a SIGUSR1 to ourselves if the echo fails with an error (due to broken pipe)
	while kill -0 $pid 2>/dev/null; do echo "." 2>/dev/null || kill -USR1 $BASHPID; sleep 0.1; done;
	
	wait $pid || exit $?
	
	exec 1>&-;
# The following pipeline blocks until grep has matched the desired text.
# Once the match has succeeded, and we're in $pipeout mode, the pipeline that follows us (outside this script), with the user test, will start running (since it is something like `{ read; curl localhost:$PORT/test | grep foo; }`, and the `read` will unblock due to our grep having output something).
# We then keep writing dots to that outer pipeline, which will start failing with SIGPIPE once the outer pipeline has finished executing.
# Once that happens, we break out of the loop, and that will cause the pipeline above (that executed the program) to also hit a SIGPIPE, and shut down the program.
) | { grep --line-buffered $grepargs -E -e "$text" && while test $pipeout; do echo "." 2>/dev/null || break; sleep 0.1; done; exec 1>&-; }

exit ${PIPESTATUS[0]}
