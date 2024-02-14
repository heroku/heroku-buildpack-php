require_relative "spec_helper"
require "securerandom"

describe "A PHP application" do
	context "like the Heroku Getting Started guide example for PHP" do
		it "deploys, works, and re-uses cached dependencies on stack change" do
			new_app_with_stack_and_platrepo("php-getting-started").deploy do |app|
				expect(successful_body(app))
				
				# we need to test inside this deploy block for the push to work (subsequent deploy or in_directory calls start with a fresh fixture copy and repo)
				
				next unless "heroku-22" == ENV['STACK'] # testing one stack change is enough
				
				expect(app.output).to include("Downloading")
				app.update_stack("heroku-20")
				# we are changing the stack to heroku-20, so we also need to adjust the platform repository accordingly, otherwise, for tests running on branches where HEROKU_PHP_PLATFORM_REPOSITORIES is set to a value, the build would use the wrong repo
				app.set_config({"HEROKU_PHP_PLATFORM_REPOSITORIES" => ENV["HEROKU_PHP_PLATFORM_REPOSITORIES"].sub("heroku-22", "heroku-20")}) if ENV["HEROKU_PHP_PLATFORM_REPOSITORIES"]
				app.commit!
				app.push!
				expect(app.output).to_not include("Downloading")
			end
		end
	end

	context "with just an index.php" do
		before(:all) do
			@app = new_app_with_stack_and_platrepo('test/fixtures/default')
			@app.deploy
			
			delimiter = SecureRandom.uuid
			run_cmds = [
				"php -v",
				"env | grep COMPOSER_",
			]
				# there are very rare cases of stderr and stdout getting read (by the dyno runner) slightly out of order
				# if that happens, the last stderr line(s) from the program might get picked up after the next thing we echo
				# for that reason, we redirect stderr to stdout
				.map { |cmd| "#{cmd} 2>&1" }
				.join("; echo -n '#{delimiter}'; ")
			retry_until retry: 3, sleep: 5 do
				# must be careful with multiline command strings, as the CLI effectively appends '; echo $?' to the command when using 'heroku run -x'
				# we put all commands into a subshell with set -e, so that one failing will abort early, but the following '; echo $?' logic still executes
				@run = expect_exit(code: 0) { @app.run("( set -e; #{run_cmds.strip}; )", :return_obj => true) }.output.split(delimiter)
			end
		end
		
		after(:all) do
			@app.teardown!
		end
		
		it "picks a default version from the expected series" do
			series = expected_default_php(ENV["STACK"])
			expect(@app.output).to match(/- php \(#{Regexp.escape(series)}\./)
			expect(@run[0]).to match(/#{Regexp.escape(series)}\./)
		end
		
		it "serves traffic" do
			expect(successful_body(@app))
		end
		
		it "has Composer defaults set" do
			expect(@run[1])
				 .to match(/^COMPOSER_MEMORY_LIMIT=536870912$/)
				.and match(/^COMPOSER_MIRROR_PATH_REPOS=1$/)
				.and match(/^COMPOSER_NO_INTERACTION=1$/)
				.and match(/^COMPOSER_PROCESS_TIMEOUT=0$/)
		end
	end
end
