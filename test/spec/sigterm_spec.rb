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
					end
				end
			end
		end
	end
end
