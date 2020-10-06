require_relative "spec_helper"

shared_examples "A PHP application with a composer.json" do |series|
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
end