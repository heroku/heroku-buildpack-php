require_relative "spec_helper"

shared_examples "A basic PHP application" do |series|
	context "with a composer.json requiring PHP #{series}" do
		before(:all) do
			@app = new_app_with_stack_and_platrepo('test/fixtures/default',
				before_deploy: -> { system("composer require --quiet --ignore-platform-reqs php '#{series}.*'") or raise "Failed to require PHP version" },
				run_multi: true
			)
			@app.deploy
		end
		
		after(:all) do
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
		
		it "uses all available RAM as PHP CLI memory_limit", :if => series.between?("7.2","8.0") do
			expect(@app.run("php -i | grep memory_limit")).to match "memory_limit => 536870912 => 536870912"
		end
		
		it "is running a PHP build that links against libc-client, libonig, libsqlite3 and libzip from the stack", :if => series.between?("7.2","8.0") do
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
end
