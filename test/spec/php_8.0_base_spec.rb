require_relative "php_shared_base"

describe "A basic PHP 8.0 application", :requires_php_on_stack => "8.0" do
	include_examples "A basic PHP application", "8.0"
	
	context "with an index.php that allows for different execution times" do
		['apache2', 'nginx'].each do |server|
			context "running the #{server} web server" do
				let(:app) {
					new_app_with_stack_and_platrepo('test/fixtures/sigterm',
						before_deploy: -> { system("composer require --quiet --ignore-platform-reqs php '8.0.*'") or raise "Failed to require PHP version" }
					)
				}
				
				# FIXME: move to php_shared.rb once all PHPs are rebuilt with that tracing capability
				it "logs slowness after configured time and sees a trace" do
					app.deploy do |app|
						# launch web server wrapped in a 20 second timeout
						# once web server is ready, `read` unblocks and we curl the sleep() script which will take a few seconds to run
						# after `curl` completes, `wait-for.it.sh` will shut down
						# ensure slowlog info and trace is there
						cmd = "./waitforit.sh 20 'ready for connections' heroku-php-#{server} --verbose -F fpm.request_slowlog_timeout.conf | { read && curl \"localhost:$PORT/index.php?wait=5\"; }"
						output = app.run(cmd)
						expect(output).to include("executing too slow")
						expect(output).to include("sleep() /app/index.php:5")
					end
				end
				
				it "logs slowness after about 3 seconds and terminates the process after about 30 seconds" do
					app.deploy do |app|
						# launch web server wrapped in a 50 second timeout
						# once web server is ready, `read` unblocks and we curl the sleep() script with a very long timeout
						# after `curl` completes, `wait-for.it.sh` will shut down
						# ensure slowlog and terminate output is there
						cmd = "./waitforit.sh 50 'ready for connections' heroku-php-#{server} --verbose | { read && curl \"localhost:$PORT/index.php?wait=35\"; }"
						output = app.run(cmd)
						expect(output).to match(/executing too slow/)
						expect(output).to match(/execution timed out/)
					end
				end
			end
		end
	end
end
