require_relative "blackfire_shared"

describe "A PHP application using ext-blackfire and, as its agent, buildpack" do
	include_examples "A PHP application using ext-blackfire and", "blackfireio/integration-heroku"
	
	# we do not have to test the following for both agent variants, and this buildpack agent variant runs slightly fewer cases in the included examples above
	
	context "with dependencies that prevent automatic installation of the extension" do
		it "receives a warning but completes the build" do
			app = new_app_with_stack_and_platrepo(
				"test/fixtures/apm/blackfire-conflict",
				config: {
					"BLACKFIRE_CLIENT_ID": ENV["BLACKFIRE_CLIENT_ID"],
					"BLACKFIRE_CLIENT_TOKEN": ENV["BLACKFIRE_CLIENT_TOKEN"],
					"BLACKFIRE_SERVER_ID": ENV["BLACKFIRE_SERVER_ID"],
					"BLACKFIRE_SERVER_TOKEN": ENV["BLACKFIRE_SERVER_TOKEN"],
				}
			)
			app.deploy do |app|
				expect(app.output).to match(/Blackfire config vars detected, installing ext-blackfire/)
				expect(app.output).to match(/no suitable version of ext-blackfire available/)
				expect(app.output).not_to match(/- ext-blackfire \(\d+\.\d+\.\d+/)
			end
		end
	end
	
	context "with dependencies that polyfill the extension" do
		it "gets the native extension auto-installed despite the polyfill" do
			app = new_app_with_stack_and_platrepo(
				"test/fixtures/apm/blackfire-polyfill",
				config: {
					"BLACKFIRE_CLIENT_ID": ENV["BLACKFIRE_CLIENT_ID"],
					"BLACKFIRE_CLIENT_TOKEN": ENV["BLACKFIRE_CLIENT_TOKEN"],
					"BLACKFIRE_SERVER_ID": ENV["BLACKFIRE_SERVER_ID"],
					"BLACKFIRE_SERVER_TOKEN": ENV["BLACKFIRE_SERVER_TOKEN"],
				}
			)
			app.deploy do |app|
				expect(app.output).to match(/Blackfire config vars detected, installing ext-blackfire/)
				expect(app.output).not_to match(/no suitable version of ext-blackfire available/)
				expect(app.output).to match(/- ext-blackfire \(\d+\.\d+\.\d+/)
			end
		end
	end
end
