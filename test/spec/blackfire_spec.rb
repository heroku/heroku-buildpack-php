require_relative "spec_helper"
require 'ansi/core'

describe "A PHP application using ext-blackfire" do
	["blackfireio/integration-heroku", "our blackfire package"].each do |agent|
		context "and #{agent}" do
			["explicitly", "without BLACKFIRE_SERVER_TOKEN", "with default BLACKFIRE_LOG_LEVEL", "implicitly"].each do |mode|
				next if mode == "without BLACKFIRE_SERVER_TOKEN" and agent == "blackfireio/integration-heroku" # blackfire buildpack would error on invalid credentials
				context "#{mode}" do
					before(:all) do
						buildpacks = [:default]
						buildpacks.unshift("https://github.com/blackfireio/integration-heroku") if agent == "blackfireio/integration-heroku"
						credentials = {
							"BLACKFIRE_CLIENT_ID" => ENV["BLACKFIRE_CLIENT_ID"],
							"BLACKFIRE_CLIENT_TOKEN" => ENV["BLACKFIRE_CLIENT_TOKEN"],
							"BLACKFIRE_SERVER_ID" => ENV["BLACKFIRE_SERVER_ID"],
							"BLACKFIRE_SERVER_TOKEN" => ENV["BLACKFIRE_SERVER_TOKEN"],
						}
						if mode == "explicitly"
							# ext-blackfire is listed as a dependency in composer.json, and a BLACKFIRE_SERVER_TOKEN/ID is provided
							@app = new_app_with_stack_and_platrepo('test/fixtures/bootopts',
								buildpacks: buildpacks,
								config: credentials.merge({ "BLACKFIRE_LOG_LEVEL" => "4"}),
								before_deploy: -> { system("composer require --quiet --ignore-platform-reqs 'php:*' 'ext-blackfire:*'") or raise "Failed to require PHP/ext-blackfire" },
								run_multi: true
							)
						elsif mode == "without BLACKFIRE_SERVER_TOKEN"
							# ext-blackfire is listed as a dependency in composer.json, but a BLACKFIRE_SERVER_TOKEN/ID is missing
							@app = new_app_with_stack_and_platrepo('test/fixtures/bootopts',
								buildpacks: buildpacks,
								config: { "BLACKFIRE_LOG_LEVEL" => "4" },
								before_deploy: -> { system("composer require --quiet --ignore-platform-reqs 'php:*' 'ext-blackfire:*'") or raise "Failed to require PHP/ext-blackfire" },
								run_multi: true
							)
						elsif mode == "with default BLACKFIRE_LOG_LEVEL"
							# ext-blackfire is listed as a dependency in composer.json, and BLACKFIRE_LOG_LEVEL is the default (1=error)
							@app = new_app_with_stack_and_platrepo('test/fixtures/bootopts',
								buildpacks: buildpacks,
								config: credentials,
								before_deploy: -> { system("composer require --quiet --ignore-platform-reqs 'php:*' 'ext-blackfire:*'") or raise "Failed to require PHP/ext-blackfire" },
								run_multi: true
							)
						else
							# a BLACKFIRE_SERVER_TOKEN/ID triggers the automatic installation of ext-blackfire at the end of the build
							@app = new_app_with_stack_and_platrepo('test/fixtures/bootopts',
								buildpacks: buildpacks,
								config: credentials.merge({ "BLACKFIRE_LOG_LEVEL" => "4"}),
								before_deploy: -> { system("composer require --quiet --ignore-platform-reqs 'php:*'") or raise "Failed to require PHP version" },
								run_multi: true
							)
						end
						@app.deploy
					end
					after(:all) do
						@app.teardown!
					end
					
					it "installs Blackfire" do
						if agent == "our blackfire package"
							expect(@app.output).not_to match(/Blackfire CLI version \d+\.\d+\.\d+ detected/)
						else
							expect(@app.output).to match(/Blackfire CLI version \d+\.\d+\.\d+ detected/)
						end
						
						if mode == "implicitly"
							expect(@app.output).to match(/Blackfire detected, installed ext-blackfire/) # auto-install at the end
						else
							if agent == "our blackfire package"
								expect(@app.output).to match(/- blackfire/)
							else
								expect(@app.output).not_to match(/- blackfire/)
							end
							
							expect(@app.output).to match(/- ext-blackfire/)
							
							if mode == "with default BLACKFIRE_LOG_LEVEL"
								expect(@app.output).not_to match(/\[Debug\] APM: disabled/) # this message should not occur if defaults are applied correctly at build time
							else
								expect(@app.output).to match(/\[Debug\] APM: disabled/)  # extension disabled during builds
							end
						end
					end
					
					['heroku-php-apache2', 'heroku-php-nginx'].each do |script|
						# without log level info, we will not see the messages we're using to test any behavior
						# but we need to assert that no info is printed at all in this case
						it "does not output info messages during startup with #{script}", if: mode == "with default BLACKFIRE_LOG_LEVEL" do
							retry_until retry: 3, sleep: 5 do
								out = @app.run("#{script} -F conf/fpm.include.broken") # prevent FPM from starting up using an invalid config, that way we don't have to wrap the server start in a `timeout` call
								expect(out).not_to match(/\[Info\]/) # this message should not occur if defaults are applied correctly
							end
						end
						it "launches blackfire CLI, but not the extension, during boot preparations, with #{script}", if: mode != "with default BLACKFIRE_LOG_LEVEL" do
							retry_until retry: 3, sleep: 5 do
								out = @app.run("#{script} -F conf/fpm.include.broken") # prevent FPM from starting up using an invalid config, that way we don't have to wrap the server start in a `timeout` call
							
								out_before_fpm, out_after_fpm = out.unansi.split("Starting php-fpm", 2)
							
								expect(out_before_fpm).to match(/Reading agent configuration file/) # that is the very first thing the agent prints
								if mode == "without BLACKFIRE_SERVER_TOKEN"
									expect(out_before_fpm).to match(/The server ID parameter is not set/)
								else
									expect(out.unansi).to match(/Waiting for new connection/) # match on whole output in case it takes a bit longer to start <up></up>
								end
								expect(out_before_fpm).not_to match(/\[Warning\] APM: Cannot start/) # extension does not attempt to start on `php-fpm -i` during boot
								expect(out_before_fpm).to match(/\[Debug\] APM: disabled/) # blackfire reports itself disabled (by us) during the various boot prep PHP invocations
							
								expect(out_after_fpm).not_to match(/\[Debug\] APM: disabled/)
								expect(out_after_fpm).to match(/\[Info\] APCu extension is not loaded/)
							end
						end
					end
				end
			end
		end
	end
end
