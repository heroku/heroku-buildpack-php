require_relative "php_shared"

describe "A PHP 7.4 application with a composer.json", :requires_php_on_stack => "7.4" do
	include_examples "A PHP application with a composer.json", "7.4"
	
	context "with an index.php that allows for different execution times" do
		['apache2', 'nginx'].each do |server|
			context "running the #{server} web server" do
				let(:app) {
					new_app_with_stack_and_platrepo('test/fixtures/sigterm',
						before_deploy: -> { system("composer require --quiet --ignore-platform-reqs php '7.4.*'") or raise "Failed to require PHP version" }
					)
				}
				
				# FIXME: move to php_shared.rb once all PHPs are rebuilt with that tracing capability
				it "logs slowness after configured time and sees a trace" do
					app.deploy do |app|
						# first, launch in the background wrapped in a 10 second timeout
						# then sleep three seconds to allow boot
						# curl the sleep() script with a timeout
						# ensure slowlog info and trace is there
						# wait for timeout process
						cmd = "timeout 10 heroku-php-apache2 -F fpm.request_slowlog_timeout.conf & sleep 3; curl \"localhost:$PORT/index.php?wait=5\"; wait"
						output = app.run(cmd)
						expect(output).to include("executing too slow")
						expect(output).to include("sleep() /app/index.php:5")
					end
				end
				
				it "logs slowness after about 3 seconds and terminates the process after about 30 seconds" do
					app.deploy do |app|
						# first, launch in the background wrapped in a 45 second timeout
						# then sleep three seconds to allow boot
						# curl the sleep() script with a very long timeout
						# ensure slowlog and terminate output is there
						# wait for timeout process
						cmd = "timeout 45 heroku-php-apache2 & sleep 3; curl \"localhost:$PORT/index.php?wait=35\"; wait"
						output = app.run(cmd)
						expect(output).to match(/executing too slow/)
						expect(output).to match(/execution timed out/)
					end
				end
			end
		end
	end
end
