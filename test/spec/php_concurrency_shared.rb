require_relative "spec_helper"

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
		
		context "setting concurrency via .user.ini memory_limit" do
			it "calculates concurrency correctly" do
				retry_until retry: 3, sleep: 5 do
					expect(expect_exit(code: 0) { @app.run("heroku-php-#{server} -tt docroot/", :return_obj => true) }.output)
						 .to match("PHP memory_limit is 32M Bytes")
						.and match("pm.max_children = 16")
				end
			end
			it "always launches at least one worker" do
				retry_until retry: 3, sleep: 5 do
					expect(expect_exit(code: 0) { @app.run("heroku-php-#{server} -tt docroot/onegig/", :return_obj => true) }.output)
						 .to match("PHP memory_limit is 1024M Bytes")
						.and match("pm.max_children = 1")
				end
			end
			it "takes precedence over a PHP-FPM memory_limit" do
				retry_until retry: 3, sleep: 5 do
					expect(expect_exit(code: 0) { @app.run("heroku-php-#{server} -tt -F conf/fpm.include.conf docroot/", :return_obj => true) }.output)
						 .to match("PHP memory_limit is 32M Bytes")
						.and match("pm.max_children = 16")
				end
			end
			it "is only done for a .user.ini directly in the document root" do
				retry_until retry: 3, sleep: 5 do
					expect(expect_exit(code: 0) { @app.run("heroku-php-#{server} -tt", :return_obj => true) }.output)
						 .to match("PHP memory_limit is 128M Bytes")
						.and match("pm.max_children = 4")
				end
			end
		end
		
		context "setting concurrency via FPM config memory_limit" do
			it "calculates concurrency correctly" do
				retry_until retry: 3, sleep: 5 do
					expect(expect_exit(code: 0) { @app.run("heroku-php-#{server} -tt -F conf/fpm.include.conf", :return_obj => true) }.output)
						 .to match("PHP memory_limit is 16M Bytes")
						.and match("pm.max_children = 32")
				end
			end
			it "always launches at least one worker" do
				retry_until retry: 3, sleep: 5 do
					expect(expect_exit(code: 0) { @app.run("heroku-php-#{server} -tt -F conf/fpm.onegig.conf", :return_obj => true) }.output)
						 .to match("PHP memory_limit is 1024M Bytes")
						.and match("pm.max_children = 1")
				end
			end
			it "takes precedence over a .user.ini memory_limit if it's a php_admin_value" do
				retry_until retry: 3, sleep: 5 do
					expect(expect_exit(code: 0) { @app.run("heroku-php-#{server} -tt -F conf/fpm.admin.conf docroot/onegig/", :return_obj => true) }.output)
						 .to match("PHP memory_limit is 24M Bytes")
						.and match("pm.max_children = 21")
				end
			end
		end
		
		context "setting WEB_CONCURRENCY explicitly" do
			it "uses the explicit value" do
				retry_until retry: 3, sleep: 5 do
					expect(expect_exit(code: 0) { @app.run("heroku-php-#{server} -tt", :return_obj => true, :heroku => {:env => "WEB_CONCURRENCY=22"}) }.output)
						 .to match("\\$WEB_CONCURRENCY env var is set, skipping automatic calculation")
						.and match("pm.max_children = 22")
				end
			end
			it "overrides a .user.ini memory_limit" do
				retry_until retry: 3, sleep: 5 do
					expect(expect_exit(code: 0) { @app.run("heroku-php-#{server} -tt docroot/onegig/", :return_obj => true, :heroku => {:env => "WEB_CONCURRENCY=22"}) }.output)
						 .to match("\\$WEB_CONCURRENCY env var is set, skipping automatic calculation")
						.and match("pm.max_children = 22")
				end
			end
			it "overrides an FPM config memory_limit" do
				retry_until retry: 3, sleep: 5 do
					expect(expect_exit(code: 0) { @app.run("heroku-php-#{server} -tt -F conf/fpm.onegig.conf", :return_obj => true, :heroku => {:env => "WEB_CONCURRENCY=22"}) }.output)
						 .to match("\\$WEB_CONCURRENCY env var is set, skipping automatic calculation")
						.and match("pm.max_children = 22")
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
	end
end
