require_relative "spec_helper"

shared_examples "A PHP application with a composer.json" do |series|
	context "requiring PHP #{series}" do
		before(:all) do
			@app = new_app_with_stack_and_platrepo('test/fixtures/default',
				before_deploy: -> { system("composer require --quiet --ignore-platform-reqs php '#{series}.*'") or raise "Failed to require PHP version" }
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
		
		it "picks a version from the desired series" do
			expect(@app.output).to match(/- php \(#{Regexp.escape(series)}\./)
			expect(@app.run('php -v')).to match(/#{Regexp.escape(series)}\./)
		end
		
		it "has Heroku php.ini defaults" do
			ini_output = @app.run('php -i')
			expect(ini_output).to match(/date.timezone => UTC/)
			                 .and match(/error_reporting => 30719/)
			                 .and match(/expose_php => Off/)
			                 .and match(/user_ini.cache_ttl => 86400/)
			                 .and match(/variables_order => EGPCS/)
		end
		
		it "uses all available RAM as PHP CLI memory_limit", :if => series.between?("7.2","7.4") do
			expect(@app.run("php -i | grep memory_limit")).to match "memory_limit => 536870912 => 536870912"
		end
		
		it "is running a PHP build that links against libc-client, libonig, libsqlite3 and libzip from the stack", :if => series.between?("7.2","7.4") && ENV["STACK"] != "cedar-14" do
			ldd_output = @app.run("ldd .heroku/php/bin/php .heroku/php/lib/php/extensions/no-debug-non-zts-*/{imap,mbstring,pdo_sqlite,sqlite3}.so | grep -E ' => (/usr)?/lib/' | grep -e 'libc-client.so' -e 'libonig.so' -e 'libsqlite3.so' -e 'libzip.so' | wc -l")
			# 1x libc-client.so for extensions/…/imap.so
			# 1x libonig for extensions/…/mbstring.so
			# 1x libsqlite3.so for extensions/…/pdo_sqlite.so
			# 1x libsqlite3.so for extensions/…/sqlite3.so
			# 1x libsqlite3.so for bin/php
			# 1x libzip.so for bin/php
			expect(ldd_output).to match(/^6$/)
		end
	end
	
	context "requiring PHP #{series} and using New Relic" do
		["explicitly", "without NEW_RELIC_LICENSE_KEY", "implicitly"].each do |mode|
			context "#{mode}" do
				before(:all) do
					if mode == "explicitly"
						# ext-newrelic is listed as a dependency in composer.json, and a NEW_RELIC_LICENSE_KEY is provided
						@app = new_app_with_stack_and_platrepo('test/fixtures/bootopts',
							config: { "NEW_RELIC_LOG_LEVEL" => "info", "NEW_RELIC_LICENSE_KEY" => "somethingfake" },
							before_deploy: -> { system("composer require --quiet --ignore-platform-reqs 'php:#{series}.*' 'ext-newrelic:*'") or raise "Failed to require PHP/ext-newrelic" }
						)
					elsif mode == "without NEW_RELIC_LICENSE_KEY"
						# ext-newrelic is listed as a dependency in composer.json, but a NEW_RELIC_LICENSE_KEY is missing
						@app = new_app_with_stack_and_platrepo('test/fixtures/bootopts',
							config: { "NEW_RELIC_LOG_LEVEL" => "info" },
							before_deploy: -> { system("composer require --quiet --ignore-platform-reqs 'php:#{series}.*' 'ext-newrelic:*'") or raise "Failed to require PHP/ext-newrelic" }
						)
					else
						# a NEW_RELIC_LICENSE_KEY triggers the automatic installation of ext-newrelic at the end of the build
						@app = new_app_with_stack_and_platrepo('test/fixtures/bootopts',
							config: { "NEW_RELIC_LOG_LEVEL" => "info", "NEW_RELIC_LICENSE_KEY" => "thiswilltriggernewrelic" },
							before_deploy: -> { system("composer require --quiet --ignore-platform-reqs 'php:#{series}.*'") or raise "Failed to require PHP version" }
						)
					end
					@app.deploy
					@app.api_rate_limit.call.formation.update(@app.name, "web", {"size" => "Standard-1X"})
				end
				
				after(:all) do
					# scale back down when we're done
					# we should do this, because teardown! doesn't remove the app unless we're over the app limit
					@app.api_rate_limit.call.formation.update(@app.name, "web", {"size" => "free"})
					@app.teardown!
				end
				
				it "installs New Relic" do
					if mode == "implicitly"
						expect(@app.output).not_to match(/New Relic PHP Agent globally disabled/) # NR daemon should never start, since NR is installed at the very end
						expect(@app.output).to match(/New Relic detected, installed ext-newrelic/) # auto-install at the end
					else
						expect(@app.output).to match(/- ext-newrelic/)
						expect(@app.output).to match(/New Relic PHP Agent globally disabled/) # NR daemon will throw this during composer install
					end
				end
				
				it "does not start New Relic during build" do
					expect(@app.output).not_to match(/listen="@newrelic-daemon".*?startup=init/) # NR daemon does not start during build
					expect(@app.output).not_to match(/daemon='@newrelic-daemon'.*?startup=agent/) # no extension connects during build
				end
				
				['heroku-php-apache2', 'heroku-php-nginx'].each do |script|
					it "launches newrelic-daemon, but not the extension, during boot preparations, with #{script}" do
						out = @app.run("#{script} -F conf/fpm.include.broken") # prevent FPM from starting up using an invalid config, that way we don't have to wrap the server start in a `timeout` call
						
						expect(out).not_to match(/spawned daemon child/) # extension does not spawn its own daemon
						
						out_before_fpm, out_after_fpm = out.split("Starting php-fpm", 2)
						
						expect(out_before_fpm).to match(/listen="@newrelic-daemon"[^\n]+?startup=init/) # NR daemon starts on boot
						expect(out_before_fpm).not_to match(/daemon='@newrelic-daemon'[^\n]+?startup=agent/) # extension does not connect to daemon before FPM starts
						expect(out_before_fpm).to match(/New Relic PHP Agent globally disabled/) # NR extension reports itself disabled
						
						expect(out_after_fpm).to match(/daemon='@newrelic-daemon'[^\n]+?startup=agent/m) # extension connects to daemon when FPM starts
					end
				end
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
					before_deploy: -> { system("composer require --quiet --ignore-platform-reqs php '#{series}.*'") or raise "Failed to require PHP version" }
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
						 .to match("PHP memory_limit is 32M Bytes")
						.and match("Starting php-fpm with 16 workers...")
				end
				it "always launches at least one worker" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server} docroot/onegig/") })
						 .to match("PHP memory_limit is 1024M Bytes")
						.and match("Starting php-fpm with 1 workers...")
				end
				it "is only done for a .user.ini directly in the document root" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server}") })
						 .to match("PHP memory_limit is 128M Bytes")
						.and match("Starting php-fpm with 4 workers...")
				end
			end
			
			context "setting concurrency via FPM config memory_limit" do
				it "calculates concurrency correctly" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server} -F conf/fpm.include.conf") })
						 .to match("PHP memory_limit is 32M Bytes")
						.and match("Starting php-fpm with 16 workers...")
				end
				it "always launches at least one worker" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server} -F conf/fpm.onegig.conf") })
						 .to match("PHP memory_limit is 1024M Bytes")
						.and match("Starting php-fpm with 1 workers...")
				end
				it "takes precedence over a .user.ini memory_limit" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server} -F conf/fpm.include.conf docroot/onegig/") })
						 .to match("PHP memory_limit is 32M Bytes")
						.and match("Starting php-fpm with 16 workers...")
				end
			end
			
			context "setting WEB_CONCURRENCY explicitly" do
				it "uses the explicit value" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server}", :heroku => {:env => "WEB_CONCURRENCY=22"}) })
						 .to match("\\$WEB_CONCURRENCY env var is set, skipping automatic calculation")
						.and match("Starting php-fpm with 22 workers...")
				end
				it "overrides a .user.ini memory_limit" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server} docroot/onegig/", :heroku => {:env => "WEB_CONCURRENCY=22"}) })
						 .to match("\\$WEB_CONCURRENCY env var is set, skipping automatic calculation")
						.and match("Starting php-fpm with 22 workers...")
				end
				it "overrides an FPM config memory_limit" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server} -F conf/fpm.onegig.conf", :heroku => {:env => "WEB_CONCURRENCY=22"}) })
						 .to match("\\$WEB_CONCURRENCY env var is set, skipping automatic calculation")
						.and match("Starting php-fpm with 22 workers...")
				end
			end
			
			context "running on a Performance-L dyno" do
				it "restricts the app to 6 GB of RAM", :if => series < "7.4" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server}", :heroku => {:size => "Performance-L"}) })
						 .to match("Detected 15032385536 Bytes of RAM")
						.and match("Limiting to 6G Bytes of RAM usage")
						.and match("Starting php-fpm with 48 workers...")
				end
				
				it "uses all available RAM for PHP-FPM workers", :unless => series < "7.4" do
					expect(expect_exit(code: 124) { @app.run("timeout 5 heroku-php-#{server}", :heroku => {:size => "Performance-L"}) })
						 .to match("Detected 15032385536 Bytes of RAM")
						.and match("Starting php-fpm with 112 workers...")
				end
			end
		end
	end
end
