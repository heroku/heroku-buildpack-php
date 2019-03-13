require_relative "spec_helper"

shared_examples "A PHP application with a composer.json" do |series|
	context "requiring PHP #{series}" do
		let(:app) {
			new_app_with_stack_and_platrepo('test/fixtures/default',
				before_deploy: -> { system("composer require --quiet --no-update php '#{series}.*' && composer update --quiet --ignore-platform-reqs") or raise "Failed to require PHP version" }
			)
		}
		it "picks a version from the desired series" do
			app.deploy do |app|
				expect(app.output).to match(/- php \(#{Regexp.escape(series)}\./)
				expect(app.run('php -v')).to match(/#{Regexp.escape(series)}\./)
			end
		end
	end
	
	# the matrix of options and arguments to test
	# we will generate relevant combinations of these using a helper
	# numeric keys mean the values are passed as an argument and not as key/value options
	# nil means the argument/option will be omitted
	# true means the option will be passed without a value
	# false means the option will be passed without a value, and the invocation will be expected to fail
	# any string value that contains "broken" will be expected to fail
	matrices = {
		"apache2" => {
			0 => [
				"heroku-php-apache2"
			],
			'-C' => [
				nil,
				"conf/apache2.server.include.conf",
				"conf/apache2.server.include.dynamic.conf.php",
				"conf/apache2.server.include.broken"
			],
			'-F' => [
				nil,
				"conf/fpm.include.conf",
				"conf/fpm.include.dynamic.conf.php",
				"conf/fpm.include.broken"
			],
			1 => [ # document root argument
				nil,
				"docroot/",
				"brokendocroot/"
			]
		},
		"nginx" => {
			0 => [
				"heroku-php-nginx"
			],
			'-C' => [
				nil,
				"conf/nginx.server.include.conf",
				"conf/nginx.server.include.dynamic.conf.php",
				"conf/nginx.server.include.broken"
			],
			'-F' => [
				nil,
				"conf/fpm.include.conf",
				"conf/fpm.include.dynamic.conf.php",
				"conf/fpm.include.broken"
			],
			1 => [ # document root argument
				nil,
				"docroot/",
				"brokendocroot/"
			]
		}
	}
	# generate combinations for given keys, or all if nil
	def self.genmatrix(matrix, keys = nil)
		product_hash(matrix.select {|k,v| !keys || keys.include?(k) })
	end
	# generate command based on given combination info hash
	def self.gencmd(args)
		args.compact.map { |k,v|
			if k.is_a? Numeric
				ret = v.shellescape # it's an argument, so we want the value only
			else
				ret = k.shellescape
				unless !!v == v # check if boolean
					ret.concat(" #{v.shellescape}") # --foobar flags have no values
				end
			end
			ret
		}.join(" ").strip
	end
	
	matrices.each do |server, matrix|
		context "running PHP #{series} and the #{server} web server" do
			before(:all) do
				@app = new_app_with_stack_and_platrepo('test/fixtures/bootopts',
					before_deploy: -> { system("composer require --quiet --no-update php '#{series}.*' && composer update --quiet --ignore-platform-reqs") or raise "Failed to require PHP version" }
				)
				@app.deploy
				# so we don't have to worry about overlapping dynos causing test failures because only one free is allowed at a time
				@app.api_rate_limit.call.formation.update(@app.name, "web", {"size" => "Standard-1X"})
			end
			
			after(:all) do
				# scale back down when we're done
				# we should do this, because teardown! doesn't remove the app unless we're over the app limit
				@app.api_rate_limit.call.formation.update(@app.name, "web", {"size" => "free"})
				@app.teardown!
			end
			
			# we don't want to test all possible combinations of all arguments, as that'd be thousands
			interesting = Array.new
			interesting << [0, 1] # with and without document root
			interesting << [0, '-C']
			interesting << [0, '-F']
			combinations = interesting.map {|v| genmatrix(matrix, v)}.flatten(1).uniq
			# # a few more "manual" cases
			combinations << {0 => "heroku-php-#{server}", "-C" => "conf/#{server}.server.include.conf", "-F" => "conf/fpm.include.conf"}
			combinations.each do | combination |
				cmd = gencmd(combination)
				context "launching using `#{cmd}'" do
					if combination.value?(false) or cmd.match("broken")
						it "does not boot" do
							# check if "timeout" exited with a status other than 124, which means the process exited (due to the expected error) before "timeout" stepped in after the given duration (five seconds) and terminated it
							expect_exit(expect: :not_to, code: 124) { @app.run("timeout 5 #{cmd}") }
						end
					else
						it "boots" do
							# check if "timeout" exited with status 124, which means the process was still alive after the given duration (five seconds) and "timeout" terminated it as a result
							expect_exit(expect: :to, code: 124) { @app.run("timeout 5 #{cmd}") }
						end
					end
				end
			end
			
			context "launching using too many arguments" do
				it "fails to boot" do
					expect_exit(expect: :not_to, code: 124) { @app.run("timeout 5 heroku-php-#{server} docroot/ anotherarg") }
				end
			end
			
			context "launching using unknown options" do
				it "fails to boot" do
					expect_exit(expect: :not_to, code: 124) { @app.run("timeout 5 heroku-php-#{server} --what -u erp") }
				end
			end
			
			context "setting concurrency via .user.ini memory_limit" do
				it "calculates concurrency correctly" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server} docroot/") })
						.to match("16 processes at 32MB memory limit")
				end
				it "always launches at least one worker" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server} docroot/onegig/") })
						.to match("1 processes at 1024MB memory limit")
				end
				it "is only done for a .user.ini directly in the document root" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server}") })
						.to match("4 processes at 128MB memory limit")
				end
			end
			
			context "setting concurrency via FPM config memory_limit" do
				it "calculates concurrency correctly" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server} -F conf/fpm.include.conf") })
						.to match("16 processes at 32MB memory limit")
				end
				it "always launches at least one worker" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server} -F conf/fpm.onegig.conf") })
						.to match("1 processes at 1024MB memory limit")
				end
				it "takes precedence over a .user.ini memory_limit" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server} -F conf/fpm.include.conf docroot/onegig/") })
						.to match("16 processes at 32MB memory limit")
				end
			end
			
			context "setting WEB_CONCURRENCY explicitly" do
				it "uses the explicit value" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server}", nil, {:heroku => {:env => "WEB_CONCURRENCY=22"}}) })
						.to match "Using WEB_CONCURRENCY=22"
				end
				it "overrides a .user.ini memory_limit" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server} docroot/onegig/", nil, {:heroku => {:env => "WEB_CONCURRENCY=22"}}) })
						.to match "Using WEB_CONCURRENCY=22"
				end
				it "overrides an FPM config memory_limit" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server} -F conf/fpm.onegig.conf", nil, {:heroku => {:env => "WEB_CONCURRENCY=22"}}) })
						.to match "Using WEB_CONCURRENCY=22"
				end
			end
		end
	end
end
