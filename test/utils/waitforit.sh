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
		  waitforit <DURATION> <TEXT_TO_MATCH> <COMMAND...>
		
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

# a temp log file which the program writes to in one 'timeout', and a tail/grep pipeline reads from in another 'timeout'
# this way, the 'tee' that duplicates all output to both the log file and stderr lives until the very end of the program's lifetime and outputs everything
# this is much simpler than chaining the two together using a pipeline, since SIGPIPE propagates through it in a funny manner, and timeout
stdout_log=$(mktemp)
stderr_log=$(mktemp)

# launch the program wrapped in a timeout, sending stderr to stdout to separate logs while maintaining their respective original "channels"
timeout $duration "$@" > >(tee "$stdout_log") 2> >(tee "$stderr_log" >&2) & pid=$!

# tail the log file in a timeout, and grep for our expected output
# once the grep returns, we keep writing output to a following pipeline (if there is one), so that a program there can do some stuff - once it's done, our echo attempts will start failing (due to SIGPIPE), and we exit
timeout $duration tail -q -F "$stdout_log" "$stderr_log" > >(grep --line-buffered $grepargs -E -e "$text" && while test $pipeout; do echo "." 2>/dev/null || break; sleep 0.1; done; ) & tid=$!

# wait for whichever returns first - could be the program "crashing" or timing out, or the tail hitting the grep expression or timing out
wait -n $pid $tid

# we first check if the tail is still alive, not if the program is still alive
# this allows testing cases where the program exits using a particular message
if kill -0 $tid 2> /dev/null; then
	wait $pid
	if [[ $? != 124 ]]; then
		kill -TERM $tid
	fi
fi

# record the exit status of the first part of the tail pipeline, so that we can differentiate between a timeout (status 124) and a successful match (status 141, SIGPIPE)
wait $tid
pipest=$?

if [[ "$pipest" == 141 ]]; then
	# if we have a match (pipe status 141), then let's shut down the program
	# it's likely the program is still alive, as it should be - shut it down, then exit 0, so that the caller can know all was well
	kill -TERM $pid 2> /dev/null
	# wait and get its real exit status
	wait $pid
	# exit 0 in all cases
	exit 0
elif [[ "$pipest" != 124 && "$pipest" != 143 ]]; then
	# if the tail did not time out, and was not killed by us... that would be weird!
	echo "$(basename $0): unexpected status ${pipest} for 'timeout tail'" >&2
fi

# the tail/grep pipeline timed out, so we had no match
# we rely on the timeout for the "main" program to kick in
wait $pid

progst=$?
if [[ "$pipest" != "$progst" ]]; then
	# we relay that exit status - it is possible that it did not exit due to timeout, but just early with some error
	exit $progst
else
	# both timed out, all is well
	exit $pipest
fi
