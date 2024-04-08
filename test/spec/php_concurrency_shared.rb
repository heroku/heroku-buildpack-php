require_relative "spec_helper"
require "securerandom"

shared_examples "A PHP application for testing WEB_CONCURRENCY behavior" do |series, server|

	context "running PHP #{series} and the #{server} web server" do
		before(:all) do
			@app = new_app_with_stack_and_platrepo('test/fixtures/bootopts',
				before_deploy: -> { system("composer require --quiet --ignore-platform-reqs php '#{series}.*'") or raise "Failed to require PHP version" },
				run_multi: true
			)
			@app.deploy
		end
		
		after(:all) do
			@app.teardown!
		end
		
		context "setting concurrency via" do
			before(:all) do
				delimiter = SecureRandom.uuid
				run_cmds = [
					"heroku-php-#{server} -tt docroot/",
					"heroku-php-#{server} -tt docroot/onegig/",
					"heroku-php-#{server} -tt -F conf/fpm.include.conf docroot/",
					"heroku-php-#{server} -tt",
					"heroku-php-#{server} -tt -F conf/fpm.include.conf",
					"heroku-php-#{server} -tt -F conf/fpm.onegig.conf",
					"heroku-php-#{server} -tt -F conf/fpm.admin.conf docroot/onegig/",
					"heroku-php-#{server} -tt -F conf/fpm.unlimited.conf",
					"WEB_CONCURRENCY=22 heroku-php-#{server} -tt",
					"WEB_CONCURRENCY=22 heroku-php-#{server} -tt docroot/onegig/",
					"WEB_CONCURRENCY=22 heroku-php-#{server} -tt -F conf/fpm.onegig.conf",
					"WEB_CONCURRENCY=zomg heroku-php-#{server} -tt",
				]
					# there are very rare cases of stderr and stdout getting read (by the dyno runner) slightly out of order
					# if that happens, the last stderr line(s) from the program might get picked up after the next thing we echo
					# for that reason, we redirect stderr to stdout
					.map { |cmd| "#{cmd} 2>&1" }
					.join("; echo -n '#{delimiter}'; ")
				retry_until retry: 3, sleep: 5 do
					# must be careful with multiline command strings, as the CLI effectively appends '; echo $?' to the command when using 'heroku run -x'
					# we put all commands into a subshell with set -e, so that one failing will abort early, but the following '; echo $?' logic still executes
					@run = expect_exit(code: 0) { @app.run("( set -e; #{run_cmds}; )", :return_obj => true) }.output.split(delimiter)
				end
			end
			
			context ".user.ini memory_limit" do
				it "calculates concurrency correctly" do
					expect(@run[0])
						 .to match("PHP memory_limit is 32M Bytes")
						.and match("pm.max_children = 16")
				end
				it "always launches at least one worker" do
					expect(@run[1])
						 .to match("PHP memory_limit is 1024M Bytes")
						.and match("pm.max_children = 1")
				end
				it "takes precedence over a PHP-FPM memory_limit" do
					expect(@run[2])
						 .to match("PHP memory_limit is 32M Bytes")
						.and match("pm.max_children = 16")
				end
				it "is only done for a .user.ini directly in the document root" do
					expect(@run[3])
						 .to match("PHP memory_limit is 128M Bytes")
						.and match("pm.max_children = 4")
				end
			end
			
			context "FPM config memory_limit" do
				it "calculates concurrency correctly" do
					expect(@run[4])
						 .to match("PHP memory_limit is 16M Bytes")
						.and match("pm.max_children = 32")
				end
				it "always launches at least one worker" do
					expect(@run[5])
						 .to match("PHP memory_limit is 1024M Bytes")
						.and match("pm.max_children = 1")
				end
				it "takes precedence over a .user.ini memory_limit if it's a php_admin_value" do
					expect(@run[6])
						 .to match("PHP memory_limit is 24M Bytes")
						.and match("pm.max_children = 21")
				end
				it "handles a negative (unlimited) memory_limit" do
					expect(@run[7])
						 .to match("PHP memory_limit is unlimited")
						.and match("pm.max_children = 1")
				end
			end
			
			context "an explicit WEB_CONCURRENCY var" do
				it "uses the explicit value" do
					expect(@run[8])
						 .to match("\\$WEB_CONCURRENCY env var is set, skipping automatic calculation")
						.and match("pm.max_children = 22")
				end
				it "overrides a .user.ini memory_limit" do
					expect(@run[9])
						 .to match("\\$WEB_CONCURRENCY env var is set, skipping automatic calculation")
						.and match("pm.max_children = 22")
				end
				it "overrides an FPM config memory_limit" do
					expect(@run[10])
						 .to match("\\$WEB_CONCURRENCY env var is set, skipping automatic calculation")
						.and match("pm.max_children = 22")
				end
				it "ignores an illegal value" do
					expect(@run[11])
						 .to match("\\$WEB_CONCURRENCY env var is set, skipping automatic calculation")
						.and include("Setting WEB_CONCURRENCY=1 (was outside allowed range)")
						.and match("pm.max_children = 1")
				end
			end
		end
		
		context "running on a Performance-L dyno" do
			it "restricts the app to 6 GB of RAM", :if => series < "7.4" do
				retry_until retry: 3, sleep: 5 do
					expect(expect_exit(code: 0) { @app.run("heroku-php-#{server} -tt", :return_obj => true, :heroku => {:size => "Performance-L"}) }.output)
						 .to match("Available RAM is 6G Bytes")
						.and match("Limiting RAM usage to 6G Bytes")
						.and match("pm.max_children = 48")
				end
			end
			
			it "uses all available RAM for PHP-FPM workers", :unless => series < "7.4" do
				retry_until retry: 3, sleep: 5 do
					expect(expect_exit(code: 0) { @app.run("heroku-php-#{server} -tt", :return_obj => true, :heroku => {:size => "Performance-L"}) }.output)
						 .to match("Available RAM is 14G Bytes")
						.and match("pm.max_children = 112")
				end
			end
		end
		
		# for these, we fake the CPU core count by "overriding" getconf
		context "running on a machine with unusual core-to-RAM ratios" do
			before(:all) do
				delimiter = SecureRandom.uuid
				# there are very rare cases of stderr and stdout getting read (by the dyno runner) slightly out of order
				# if that happens, the last stderr line(s) from the program might get picked up after the next thing we echo
				# for that reason, we redirect stderr to stdout
				run_cmds = [<<~CMD1, <<~CMD2, <<~CMD3].map { |cmd| cmd.strip }.map { |cmd| "#{cmd} 2>&1" }.join("; echo -n '#{delimiter}'; ")
					getconf() { echo '_NPROCESSORS_ONLN                  1'; }
					export -f getconf
					heroku-php-#{server} -v -tt 2>&1
				CMD1
					getconf() { echo '_NPROCESSORS_ONLN                  16'; }
					heroku-php-#{server} -v -tt 2>&1
				CMD2
					getconf() { echo '_NPROCESSORS_ONLN                  1'; }
					heroku-php-#{server} -v -tt -F conf/fpm.admin.conf 2>&1
				CMD3
				retry_until retry: 3, sleep: 5 do
					# must be careful with multiline command strings, as the CLI effectively appends '; echo $?' to the command when using 'heroku run -x'
					# we put all commands into a subshell with set -e, so that one failing will abort early, but the following '; echo $?' logic still executes
					@run = expect_exit(code: 0) { @app.run("( set -e; #{run_cmds.strip}; )", :return_obj => true, :heroku => {:size => "Performance-M"}) }.output.split(delimiter)
				end
			end
			
			it "calculates a worker count that does not vastly exceed CPU core capacity" do
				expect(@run[0])
					 .to match(/Available RAM is 2560M Bytes$/)
					.and match(/Number of CPU cores is 1$/)
					.and match(/Calculated number of workers based on RAM and CPU cores is 10$/)
					.and match(/Maximum number of workers that fit available RAM at memory_limit is 20$/)
					.and match(/Limiting number of workers to 10$/)
					.and match(/pm.max_children = 10$/)
			end
			it "calculates a worker count whose cumulative memory_limit will not exceed available RAM" do
				expect(@run[1])
					 .to match(/Available RAM is 2560M Bytes$/)
					.and match(/Number of CPU cores is 16$/)
					.and match(/Calculated number of workers based on RAM and CPU cores is 160$/)
					.and match(/Maximum number of workers that fit available RAM at memory_limit is 20$/)
					.and match(/Limiting number of workers to 20$/)
					.and match(/pm.max_children = 20$/)
			end
			it "calculates a correct worker count for memory_limits that divide available RAM with a remainder" do
				expect(@run[2])
					 .to match(/Available RAM is 2560M Bytes$/)
					.and match(/Number of CPU cores is 1$/)
					.and match(/Calculated number of workers based on RAM and CPU cores is 53$/)
					.and match(/Maximum number of workers that fit available RAM at memory_limit is 106$/)
					.and match(/Limiting number of workers to 53$/)
					.and match(/pm.max_children = 53$/)
			end
		end
	end
end
