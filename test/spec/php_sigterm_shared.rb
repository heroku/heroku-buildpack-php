require_relative "spec_helper"

shared_examples "A PHP application with long-running requests" do |series, server|
	context "that uses PHP #{series} and the #{server} web server" do
		before(:all) do
			@app = new_app_with_stack_and_platrepo('test/fixtures/sigterm',
				before_deploy: -> { system("composer require --quiet --ignore-platform-reqs php '#{series}.*'") or raise "Failed to require PHP version" },
				run_multi: true
			)
			@app.deploy
		end
		
		after(:all) do
			@app.teardown!
		end
		
		it "gracefully shuts down when the leader process receives a SIGTERM" do
			# first, launch in the background and get the pid
			# then sleep five seconds to allow boot (semicolon before ! needs a space, Bash...)
			# curl the sleep() script (and remember the curl pid)
			# pgrep all our user's PIDs, then inverse-grep away $$ (that's our shell) and the curl PID
			# we issue two SIGTERMs to ensure that the leader process handles the arrival of multiple signals correctly
			# wait for $pid so that we can be certain to get all the output
			# finally, with a kill -0, check if any of the processes we wanted to terminate are still alive - nothing should be!
			cmd = "heroku-php-#{server} & pid=$! ; sleep 5; curl \"localhost:$PORT/index.php?wait=5\" & curlpid=$!; sleep 2; pidlist=$(pgrep -U $UID | grep -vw -e $$ -e $curlpid); kill $pid & kill $pid; sleep 0.1; kill $pid 2>/dev/null; wait $pid; kill -0 $pidlist 2>/dev/null && { echo 'Oh no, processes left behind:'; ps afx o user,pgid,pid,comm; }"
			retry_until retry: 3, sleep: 5 do
				# exit status should be 1 - the last 'kill -0' should not have found any of the given PIDs
				output = expect_exit(expect: :to, code: 1) { @app.run(cmd, :return_obj => true) }.output
				expect(output).to match(/^hello world after 5\d{9} us \(expected 5 s\)$/)
				expect(output).to match(/^request complete$/) # ensure a late log line is captured, meaning the logs tail process stays alive until the end
			end
		end
		
		it "gracefully shuts down when all processes receive a SIGTERM because HEROKU_PHP_GRACEFUL_SIGTERM is on by default" do
			# first, launch in the background and get the pid
			# then sleep five seconds to allow boot (semicolon before ! needs a space, Bash...)
			# curl the sleep() script (and remember the curl pid)
			# pgrep all our user's PIDs, then inverse-grep away $$ (that's our shell) and the curl PID
			# hand all those PIDs to kill
			# we issue two SIGTERMs to ensure that the leader process handles the arrival of multiple signals correctly
			# wait for $pid so that we can be certain to get all the output
			# finally, with a kill -0, check if any of the processes we wanted to terminate are still alive - nothing should be!
			cmd = "heroku-php-#{server} & pid=$! ; sleep 5; curl \"localhost:$PORT/index.php?wait=5\" & curlpid=$!; sleep 2; pidlist=$(pgrep -U $UID | grep -vw -e $$ -e $curlpid); kill $pidlist 2>/dev/null & kill $pidlist 2>/dev/null; sleep 0.1; kill $pidlist 2>/dev/null; wait $pid; kill -0 $pidlist 2>/dev/null && { echo 'Oh no, processes left behind:'; ps afx o user,pgid,pid,comm; }"
			retry_until retry: 3, sleep: 5 do
				# exit status should be 1 - the last 'kill -0' should not have found any of the given PIDs
				output = expect_exit(expect: :to, code: 1) { @app.run(cmd, :return_obj => true) }.output
				expect(output).to match(/^hello world after 5\d{9} us \(expected 5 s\)$/)
				expect(output).to match(/^request complete$/) # ensure a late log line is captured, meaning the logs tail process stays alive until the end
			end
		end
		
		it "logs slowness, prints a trace, and terminates the process after configured timeouts" do
			wait_script = "index.php"
			wait_line = 17
			wait_secs = 5
			timeout_secs = 3
			# launch web server wrapped in a 10 second timeout
			# once web server is ready, `read` unblocks and we curl the sleep() script which will take a few seconds to run
			# after `curl` completes, `waitforit.sh` will shut down
			cmd = "./waitforit.sh 10 'ready for connections' heroku-php-#{server} -F fpm.request_slowlog_timeout.conf --verbose | { read && curl \"localhost:$PORT/#{wait_script}?wait=#{wait_secs}\"; }"
			retry_until retry: 3, sleep: 5 do
				output = @app.run(cmd)
				# ensure slowlog info and trace is there
				expect(output).to include("executing too slow")
				expect(output).to include("wait() /app/#{wait_script}:#{wait_line}")
				# FPM only logs the timeout once, because it successfully terminates the process
				expect(output.scan(/execution timed out/).size).to eq(1)
				# fetch child PID that it wanted to terminate
				child = output.match(/WARNING: \[pool www\] child (?<cpid>\d+), script '\/app\/#{Regexp.escape(wait_script)}' \(request: "GET \/#{Regexp.escape(wait_script)}\?wait=#{wait_secs}"\) execution timed out \(#{timeout_secs}\.\d+ sec\), terminating$/)
				expect(child).not_to be_nil
				# check that this child was, indeed, terminated
				expect(/WARNING: \[pool www\] child (?<cpid>\d+) exited on signal 2 \(SIGINT\) after #{timeout_secs}\.\d+ seconds from start/).to match(output).with_captures(:cpid => child[:cpid])
				# ensure the child did not complete
				expect(output).not_to include("hello world")
				expect(output).not_to include("request complete")
			end
		end
		
		it "is configured to log slow requests after 3 seconds and terminate them after 30 seconds" do
			# we can parse this from the config test output (-tt tests config and dumps PHP-FPM config)
			cmd = "heroku-php-#{server} -tt"
			retry_until retry: 3, sleep: 5 do
				output = @app.run(cmd)
				# ensure slowlog info and trace is there
				expect(output).to include("request_slowlog_timeout = 3s")
				expect(output).to include("request_terminate_timeout = 30s")
			end
		end
	end
end
