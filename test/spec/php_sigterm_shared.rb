require_relative "spec_helper"

shared_examples "A PHP application with long-running requests" do |series|
	context "that uses #{series}" do
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
		
		['apache2', 'nginx'].each do |server|
			context "running the #{server} web server" do
				it "gracefully shuts down when the leader process receives a SIGTERM" do
					# first, launch in the background and get the pid
					# then sleep five seconds to allow boot (semicolon before ! needs a space, Bash...)
					# curl the sleep() script, kill it after two seconds
					# wait for $pid so that we can be certain to get all the output
					cmd = "heroku-php-#{server} & pid=$! ; sleep 5; curl \"localhost:$PORT/index.php?wait=5\" & sleep 2; kill $pid; wait $pid"
					retry_until retry: 3, sleep: 5 do
						output = @app.run(cmd)
						expect(output).to match(/^hello world after 5 second\(s\)$/)
						expect(output).to match(/^request complete$/) # ensure a late log line is captured, meaning the logs tail process stays alive until the end
					end
				end
				
				it "gracefully shuts down when all processes receive a SIGTERM because HEROKU_PHP_GRACEFUL_SIGTERM is on by default" do
					# first, launch in the background and get the pid
					# then sleep five seconds to allow boot (semicolon before ! needs a space, Bash...)
					# curl the sleep() script (and remember the curl pid)
					# pgrep all our user's PIDs, then inverse-grep away $$ (that's our shell) and the curl PID
					# hand all those PIDs to kill
					# wait for $pid so that we can be certain to get all the output
					cmd = "heroku-php-#{server} & pid=$! ; sleep 5; curl \"localhost:$PORT/index.php?wait=5\" & curlpid=$!; sleep 2; kill $(pgrep -U $UID | grep -vw -e $$ -e $curlpid) 2>/dev/null; wait $pid"
					retry_until retry: 3, sleep: 5 do
						output = @app.run(cmd)
						expect(output).to match(/^hello world after 5 second\(s\)$/)
						expect(output).to match(/^request complete$/) # ensure a late log line is captured, meaning the logs tail process stays alive until the end
					end
				end
				
				it "logs slowness after about 3 seconds, prints a trace, and terminates the process after about 30 seconds" do
					# launch web server wrapped in a 40 second timeout
					# once web server is ready, `read` unblocks and we curl the sleep() script which will take a few seconds to run
					# after `curl` completes, `waitforit.sh` will shut down
					cmd = "./waitforit.sh 40 'ready for connections' heroku-php-#{server} --verbose | { read && curl \"localhost:$PORT/index.php?wait=35\"; }"
					retry_until retry: 3, sleep: 5 do
						output = @app.run(cmd)
						# ensure slowlog info and trace is there
						expect(output).to include("executing too slow")
						expect(output).to include("sleep() /app/index.php:5")
						# ensure termination info is there
						expect(output).to match(/execution timed out/)
					end
				end
			end
		end
	end
end
