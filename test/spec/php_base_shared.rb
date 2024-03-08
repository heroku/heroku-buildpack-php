require_relative "spec_helper"
require "securerandom"

shared_examples "A basic PHP application" do |series|
	context "with a composer.json requiring PHP #{series}" do
		before(:all) do
			@app = new_app_with_stack_and_platrepo('test/fixtures/default',
				before_deploy: -> { system("composer require --quiet --ignore-platform-reqs php '#{series}.*'") or raise "Failed to require PHP version" }
			)
			@app.deploy
			
			delimiter = SecureRandom.uuid
			run_cmds = [
				"php -v",
				"php -i",
				"php -i | grep memory_limit",
				"ldd .heroku/php/bin/php .heroku/php/lib/php/extensions/no-debug-non-zts-*/{imap,mbstring,pdo_sqlite,sqlite3}.so | grep -E ' => (/usr)?/lib/' | grep -e 'libc-client.so' -e 'libonig.so' -e 'libsqlite3.so' -e 'libzip.so' | wc -l",
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
		
		it "picks a version from the desired series" do
			expect(@app.output).to match(/- php \(#{Regexp.escape(series)}\./)
			expect(@run[0]).to match(/#{Regexp.escape(series)}\./)
		end
		
		it "has Heroku php.ini defaults" do
			expect(@run[1])
				 .to match(/date.timezone => UTC/)
				.and match(/error_reporting => 30719/)
				.and match(/expose_php => Off/)
				.and match(/user_ini.cache_ttl => 86400/)
				.and match(/variables_order => EGPCS/)
		end
		
		it "uses all available RAM as PHP CLI memory_limit" do
			expect(@run[2]).to match("memory_limit => 536870912 => 536870912")
		end
		
		it "is running a PHP build that links against libc-client, libonig, libsqlite3 and libzip from the stack" do
			# 1x libc-client.so for extensions/…/imap.so
			# 1x libonig for extensions/…/mbstring.so
			# 1x libsqlite3.so for extensions/…/pdo_sqlite.so
			# 1x libsqlite3.so for extensions/…/sqlite3.so
			# 1x libsqlite3.so for bin/php (before heroku-22)
			# 1x libzip.so for bin/php
			if "heroku-20" == ENV['STACK']
				expect(@run[3]).to match(/^6$/)
			else
				expect(@run[3]).to match(/^5$/)
			end
		end
	end
end
