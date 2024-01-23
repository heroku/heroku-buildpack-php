require_relative "php_base_shared"

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
				it "logs slowness after about 3 seconds, prints a trace, and terminates the process after about 30 seconds" do
					app.deploy do |app|
						# launch web server wrapped in a 40 second timeout
						# once web server is ready, `read` unblocks and we curl the sleep() script which will take a few seconds to run
						# after `curl` completes, `waitforit.sh` will shut down
						cmd = "./waitforit.sh 40 'ready for connections' heroku-php-#{server} --verbose | { read && curl \"localhost:$PORT/index.php?wait=35\"; }"
						retry_until retry: 3, sleep: 5 do
							output = app.run(cmd)
							# ensure slowlog info and trace is there
							expect(output).to include("executing too slow")
							expect(output).to include("sleep() /app/index.php:5")
							# ensure termination info is there
							expect(output).to match(/execution timed out/)
							expect(output).to match(/exited on signal/)
						end
					end
				end
			end
		end
	end
end
