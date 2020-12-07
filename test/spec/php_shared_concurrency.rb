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
				expect(expect_exit(code: 0) { @app.run("./waitforit.sh 15 'ready for connections' heroku-php-#{server} --verbose docroot/", :return_obj => true) }.output)
					 .to match("PHP memory_limit is 32M Bytes")
					.and match("Starting php-fpm with 16 workers...")
			end
			it "always launches at least one worker" do
				expect(expect_exit(code: 0) { @app.run("./waitforit.sh 15 'ready for connections' heroku-php-#{server} --verbose docroot/onegig/", :return_obj => true) }.output)
					 .to match("PHP memory_limit is 1024M Bytes")
					.and match("Starting php-fpm with 1 workers...")
			end
			it "is only done for a .user.ini directly in the document root" do
				expect(expect_exit(code: 0) { @app.run("./waitforit.sh 15 'ready for connections' heroku-php-#{server} --verbose", :return_obj => true) }.output)
					 .to match("PHP memory_limit is 128M Bytes")
					.and match("Starting php-fpm with 4 workers...")
			end
		end
		
		context "setting concurrency via FPM config memory_limit" do
			it "calculates concurrency correctly" do
				expect(expect_exit(code: 0) { @app.run("./waitforit.sh 15 'ready for connections' heroku-php-#{server} --verbose -F conf/fpm.include.conf", :return_obj => true) }.output)
					 .to match("PHP memory_limit is 32M Bytes")
					.and match("Starting php-fpm with 16 workers...")
			end
			it "always launches at least one worker" do
				expect(expect_exit(code: 0) { @app.run("./waitforit.sh 15 'ready for connections' heroku-php-#{server} --verbose -F conf/fpm.onegig.conf", :return_obj => true) }.output)
					 .to match("PHP memory_limit is 1024M Bytes")
					.and match("Starting php-fpm with 1 workers...")
			end
			it "takes precedence over a .user.ini memory_limit" do
				expect(expect_exit(code: 0) { @app.run("./waitforit.sh 15 'ready for connections' heroku-php-#{server} --verbose -F conf/fpm.include.conf docroot/onegig/", :return_obj => true) }.output)
					 .to match("PHP memory_limit is 32M Bytes")
					.and match("Starting php-fpm with 16 workers...")
			end
		end
		
		context "setting WEB_CONCURRENCY explicitly" do
			it "uses the explicit value" do
				expect(expect_exit(code: 0) { @app.run("./waitforit.sh 15 'ready for connections' heroku-php-#{server} --verbose", :return_obj => true, :heroku => {:env => "WEB_CONCURRENCY=22"}) }.output)
					 .to match("\\$WEB_CONCURRENCY env var is set, skipping automatic calculation")
					.and match("Starting php-fpm with 22 workers...")
			end
			it "overrides a .user.ini memory_limit" do
				expect(expect_exit(code: 0) { @app.run("./waitforit.sh 15 'ready for connections' heroku-php-#{server} --verbose docroot/onegig/", :return_obj => true, :heroku => {:env => "WEB_CONCURRENCY=22"}) }.output)
					 .to match("\\$WEB_CONCURRENCY env var is set, skipping automatic calculation")
					.and match("Starting php-fpm with 22 workers...")
			end
			it "overrides an FPM config memory_limit" do
				expect(expect_exit(code: 0) { @app.run("./waitforit.sh 15 'ready for connections' heroku-php-#{server} --verbose -F conf/fpm.onegig.conf", :return_obj => true, :heroku => {:env => "WEB_CONCURRENCY=22"}) }.output)
					 .to match("\\$WEB_CONCURRENCY env var is set, skipping automatic calculation")
					.and match("Starting php-fpm with 22 workers...")
			end
		end
		
		context "running on a Performance-L dyno" do
			it "restricts the app to 6 GB of RAM", :if => series < "7.4" do
				expect(expect_exit(code: 0) { @app.run("./waitforit.sh 15 'ready for connections' heroku-php-#{server} --verbose", :return_obj => true, :heroku => {:size => "Performance-L"}) }.output)
					 .to match("Detected 15032385536 Bytes of RAM")
					.and match("Limiting to 6G Bytes of RAM usage")
					.and match("Starting php-fpm with 48 workers...")
			end
			
			it "uses all available RAM for PHP-FPM workers", :unless => series < "7.4" do
				expect(expect_exit(code: 0) { @app.run("./waitforit.sh 15 'ready for connections' heroku-php-#{server} --verbose", :return_obj => true, :heroku => {:size => "Performance-L"}) }.output)
					 .to match("Detected 15032385536 Bytes of RAM")
					.and match("Starting php-fpm with 112 workers...")
			end
		end
	end
end
