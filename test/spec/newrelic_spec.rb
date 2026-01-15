require_relative "spec_helper"
require "securerandom"

describe "A PHP application using New Relic" do
	["explicitly", "without NEW_RELIC_LICENSE_KEY", "with default NEW_RELIC_LOG_LEVEL", "implicitly"].each do |mode|
		context "#{mode}" do
			before(:all) do
				if mode == "explicitly"
					# ext-newrelic is listed as a dependency in composer.json, and a NEW_RELIC_LICENSE_KEY is provided
					@app = new_app_with_stack_and_platrepo('test/fixtures/bootopts',
						config: { "NEW_RELIC_LOG_LEVEL" => "info", "NEW_RELIC_LICENSE_KEY" => "somethingfake" },
						before_deploy: -> { system("composer require --quiet --ignore-platform-reqs --no-install 'php:*' 'ext-newrelic:*'") or raise "Failed to require PHP/ext-newrelic" }
					)
				elsif mode == "without NEW_RELIC_LICENSE_KEY"
					# ext-newrelic is listed as a dependency in composer.json, but a NEW_RELIC_LICENSE_KEY is missing
					@app = new_app_with_stack_and_platrepo('test/fixtures/bootopts',
						config: { "NEW_RELIC_LOG_LEVEL" => "info" },
						before_deploy: -> { system("composer require --quiet --ignore-platform-reqs --no-install 'php:*' 'ext-newrelic:*'") or raise "Failed to require PHP/ext-newrelic" }
					)
				elsif mode == "with default NEW_RELIC_LOG_LEVEL"
					# ext-newrelic is listed as a dependency in composer.json, and NEW_RELIC_LOG_LEVEL is the default (warning)
					@app = new_app_with_stack_and_platrepo('test/fixtures/bootopts',
						config: { "NEW_RELIC_LICENSE_KEY" => "somethingfake" },
						before_deploy: -> { system("composer require --quiet --ignore-platform-reqs --no-install 'php:*' 'ext-newrelic:*'") or raise "Failed to require PHP/ext-newrelic" }
					)
				else
					# a NEW_RELIC_LICENSE_KEY triggers the automatic installation of ext-newrelic at the end of the build
					@app = new_app_with_stack_and_platrepo('test/fixtures/bootopts',
						config: { "NEW_RELIC_LOG_LEVEL" => "info", "NEW_RELIC_LICENSE_KEY" => "thiswilltriggernewrelic" },
						before_deploy: -> { system("composer require --quiet --ignore-platform-reqs --no-install 'php:*'") or raise "Failed to require PHP version" }
					)
				end
				@app.deploy
			end
			
			after(:all) do
				@app.teardown!
			end
			
			it "installs New Relic" do
				platform_installs, apm_installs = @app.output.split("Checking for additional extensions to install", 2)
				if mode == "implicitly"
					# auto-install at the end of the build
					expect(apm_installs).to match(/New Relic config var detected, installing ext-newrelic/)
				end
				expect(mode == "implicitly" ? apm_installs : platform_installs).to match(/- ext-newrelic \(\d+\.\d+\.\d+/)
			end
			
			it "does not start New Relic daemon during build" do
				if mode == "implicitly" or mode == "with default NEW_RELIC_LOG_LEVEL"
					# either NR daemon should never start, since NR is installed at the very end
					# or the default log level should prevent any messages from appearing
					expect(@app.output).not_to match(/New Relic PHP Agent globally disabled/)
				else
					# this will be printed during composer install:
					# - the extension is loaded into PHP at that point
					# - the set log level allows printing
					expect(@app.output).to match(/New Relic PHP Agent globally disabled/)
				end
				expect(@app.output).not_to match(/listen="@newrelic-daemon".*?startup=init/) # NR daemon does not start during build
				expect(@app.output).not_to match(/daemon='@newrelic-daemon'.*?startup=agent/) # no extension connects during build
			end
			
			context "during boot" do
				cases = ['heroku-php-apache2', 'heroku-php-nginx']
				before(:all) do
					delimiter = SecureRandom.uuid
					# prevent FPM from starting up using an invalid config, that way we don't have to wrap the server start in a `timeout` call
					# there are very rare cases of stderr and stdout getting read (by the dyno runner) slightly out of order
					# if that happens, the last stderr line(s) from the program might get picked up after the next thing we echo
					# for that reason, we redirect stderr to stdout
					run_cmds = cases
						.map { |script| "#{script} -F conf/fpm.include.broken 2>&1"}
						.join("; echo -n '#{delimiter}'; ")
					retry_until retry: 3, sleep: 5 do
						@run = @app.run(run_cmds).split(delimiter)
					end
				end
				
				# these we check only once - it's stuff that happens in .profile.d on boot, not on each script run
				it "does not log info messages about daemon startup", if: mode == "with default NEW_RELIC_LOG_LEVEL" do
					# without log level info, we will not see the messages we're using to test any behavior
					# but we need to assert that no info is printed at all in this case
					expect(@run[0]).not_to match(/New Relic daemon/) # this message should not occur if defaults are applied correctly
				end
				it "logs info messages about daemon startup", if: mode != "with default NEW_RELIC_LOG_LEVEL" do
					out_before_fpm, out_after_fpm = @run[0].split("Starting php-fpm", 2)
					expect(out_before_fpm).to match(/listen="@newrelic-daemon"[^\n]+?startup=init/) # NR daemon starts on boot
				end
				
				# these others we check for each script invocation
				cases.each_with_index do |script, idx|
					# without log level info, we will not see the messages we're using to test any behavior
					# but we need to assert that no info is printed at all in this case
					it "does not output info messages during startup with #{script}", if: mode == "with default NEW_RELIC_LOG_LEVEL" do
						# these messages should not occur if defaults are applied correctly
						expect(@run[idx]).not_to match(/New Relic daemon/)
						expect(@run[idx]).not_to match(/New Relic PHP Agent globally disabled/)
					end
					it "launches newrelic-daemon, but not the extension, during boot preparations, with #{script}", if: mode != "with default NEW_RELIC_LOG_LEVEL" do
						out = @run[idx]
						expect(out).not_to match(/spawned daemon child/) # extension does not spawn its own daemon
						
						out_before_fpm, out_after_fpm = out.split("Starting php-fpm", 2)
						
						expect(out_before_fpm).not_to match(/daemon='@newrelic-daemon'[^\n]+?startup=agent/) # extension does not connect to daemon before FPM starts
						expect(out_before_fpm).to match(/New Relic PHP Agent globally disabled/) # NR extension reports itself disabled
						
						expect(out_after_fpm).to match(/daemon='@newrelic-daemon'[^\n]+?startup=agent/m) # extension connects to daemon when FPM starts
					end
				end
			end
		end
	end
	
	context "with dependencies that prevent automatic installation of the extension" do
		it "receives a warning but completes the build" do
			app = new_app_with_stack_and_platrepo(
				"test/fixtures/apm/newrelic-conflict",
				config: {
					"NEW_RELIC_LICENSE_KEY": "somethingfake",
				}
			)
			app.deploy do |app|
				expect(app.output).to match(/New Relic config var detected, installing ext-newrelic/)
				expect(app.output).to match(/no suitable version of ext-newrelic available/)
				expect(app.output).not_to match(/- ext-newrelic \(\d+\.\d+\.\d+/)
			end
		end
	end
	
	context "with dependencies that polyfill the extension" do
		it "gets the native extension auto-installed despite the polyfill" do
			app = new_app_with_stack_and_platrepo(
				"test/fixtures/apm/newrelic-polyfill",
				config: {
					"NEW_RELIC_LICENSE_KEY": "somethingfake",
				}
			)
			app.deploy do |app|
				expect(app.output).to match(/New Relic config var detected, installing ext-newrelic/)
				expect(app.output).not_to match(/no suitable version of ext-newrelic available/)
				expect(app.output).to match(/- ext-newrelic \(\d+\.\d+\.\d+/)
			end
		end
	end
end
