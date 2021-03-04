require_relative "spec_helper"

describe "A PHP application" do
	context "with an index.php that allows for different execution times" do
		['apache2', 'nginx'].each do |server|
			context "running the #{server} web server" do
				let(:app) {
					new_app_with_stack_and_platrepo('test/fixtures/sigterm')
				}
				
				it "gracefully shuts down when the leader process receives a SIGTERM" do
					app.deploy do |app|
						# first, launch in the background and get the pid
						# then sleep five seconds to allow boot (semicolon before ! needs a space, Bash...)
						# curl the sleep() script, kill it after two seconds
						# wait for $pid so that we can be certain to get all the output
						cmd = "heroku-php-#{server} & pid=$! ; sleep 5; curl \"localhost:$PORT/index.php?wait=5\" & sleep 2; kill $pid; wait $pid"
						output = app.run(cmd)
						expect(output).to match(/^hello world after 5 second\(s\)$/)
						expect(output).to match(/^request complete$/) # ensure a late log line is captured, meaning the logs tail process stays alive until the end
					end
				end
				
				it "gracefully shuts down when all processes receives a SIGTERM and HEROKU_PHP_GRACEFUL_SIGTERM is set" do
					app.deploy do |app|
						# first, launch in the background and get the pid
						# then sleep five seconds to allow boot (semicolon before ! needs a space, Bash...)
						# curl the sleep() script (and remember the curl pid)
						# pgrep all our user's PIDs, then inverse-grep away $$ (that's our shell) and the curl PID
						# hand all those PIDs to kill
						# wait for $pid so that we can be certain to get all the output
						cmd = "heroku-php-#{server} & pid=$! ; sleep 5; curl \"localhost:$PORT/index.php?wait=5\" & curlpid=$!; sleep 2; kill $(pgrep -U $UID | grep -vw -e $$ -e $curlpid) 2>/dev/null; wait $pid"
						output = app.run(cmd, { :heroku => { "env" => "HEROKU_PHP_GRACEFUL_SIGTERM=1" }} )
						expect(output).to match(/^hello world after 5 second\(s\)$/)
						expect(output).to match(/^request complete$/) # ensure a late log line is captured, meaning the logs tail process stays alive until the end
					end
				end
			end
		end
	end
end
