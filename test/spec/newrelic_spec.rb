require_relative "spec_helper"

describe "A PHP application using New Relic" do
	["explicitly", "without NEW_RELIC_LICENSE_KEY", "with default NEW_RELIC_LOG_LEVEL", "implicitly"].each do |mode|
		context "#{mode}" do
			before(:all) do
				if mode == "explicitly"
					# ext-newrelic is listed as a dependency in composer.json, and a NEW_RELIC_LICENSE_KEY is provided
					@app = new_app_with_stack_and_platrepo('test/fixtures/bootopts',
						config: { "NEW_RELIC_LOG_LEVEL" => "info", "NEW_RELIC_LICENSE_KEY" => "somethingfake" },
						before_deploy: -> { system("composer require --quiet --ignore-platform-reqs 'php:*' 'ext-newrelic:*'") or raise "Failed to require PHP/ext-newrelic" },
						run_multi: true
					)
				elsif mode == "without NEW_RELIC_LICENSE_KEY"
					# ext-newrelic is listed as a dependency in composer.json, but a NEW_RELIC_LICENSE_KEY is missing
					@app = new_app_with_stack_and_platrepo('test/fixtures/bootopts',
						config: { "NEW_RELIC_LOG_LEVEL" => "info" },
						before_deploy: -> { system("composer require --quiet --ignore-platform-reqs 'php:*' 'ext-newrelic:*'") or raise "Failed to require PHP/ext-newrelic" },
						run_multi: true
					)
				elsif mode == "with default NEW_RELIC_LOG_LEVEL"
					# ext-newrelic is listed as a dependency in composer.json, and NEW_RELIC_LOG_LEVEL is the default (warning)
					@app = new_app_with_stack_and_platrepo('test/fixtures/bootopts',
						config: { "NEW_RELIC_LICENSE_KEY" => "somethingfake" },
						before_deploy: -> { system("composer require --quiet --ignore-platform-reqs 'php:*' 'ext-newrelic:*'") or raise "Failed to require PHP/ext-newrelic" },
						run_multi: true
					)
				else
					# a NEW_RELIC_LICENSE_KEY triggers the automatic installation of ext-newrelic at the end of the build
					@app = new_app_with_stack_and_platrepo('test/fixtures/bootopts',
						config: { "NEW_RELIC_LOG_LEVEL" => "info", "NEW_RELIC_LICENSE_KEY" => "thiswilltriggernewrelic" },
						before_deploy: -> { system("composer require --quiet --ignore-platform-reqs 'php:7.*'") or raise "Failed to require PHP version" },
						run_multi: true
					)
				end
				@app.deploy
			end
			
			after(:all) do
				@app.teardown!
			end
			
			it "installs New Relic" do
				if mode == "implicitly"
					expect(@app.output).not_to match(/New Relic PHP Agent globally disabled/) # NR daemon should never start, since NR is installed at the very end
					expect(@app.output).to match(/New Relic detected, installed ext-newrelic/) # auto-install at the end
				else
					expect(@app.output).to match(/- ext-newrelic/)
					if mode == "with default NEW_RELIC_LOG_LEVEL"
						expect(@app.output).not_to match(/New Relic PHP Agent globally disabled/) # this message should not occur if defaults are applied correctly even at build time
					else
						expect(@app.output).to match(/New Relic PHP Agent globally disabled/) # NR daemon will throw this during composer install
					end
				end
			end
			
			it "does not start New Relic daemon during build" do
				expect(@app.output).not_to match(/listen="@newrelic-daemon".*?startup=init/) # NR daemon does not start during build
				expect(@app.output).not_to match(/daemon='@newrelic-daemon'.*?startup=agent/) # no extension connects during build
			end
			
			['heroku-php-apache2', 'heroku-php-nginx'].each do |script|
				if mode == "with default NEW_RELIC_LOG_LEVEL"
					# without log level info, we will not see the messages we're using to test any behavior
					# but we need to assert that no info is printed at all in this case
					it "does not output info messages during startup with #{script}" do
						out = @app.run("#{script} -F conf/fpm.include.broken") # prevent FPM from starting up using an invalid config, that way we don't have to wrap the server start in a `timeout` call
						
						expect(out).not_to match(/New Relic PHP Agent globally disabled/) # this message should not occur if defaults are applied correctly even at build time
						expect(out).not_to match(/New Relic daemon/) # this message should not occur if defaults are applied correctly even at build time
					end
					next # the other tests do not apply to this case since the log level isn't sufficient to assert anything
				end
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
