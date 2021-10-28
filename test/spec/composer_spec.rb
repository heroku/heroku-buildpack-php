require_relative "spec_helper"

describe "A PHP application" do
	context "with a composer.lock generatead by an old version of Composer" do
		it "builds using Composer 1.x" do
			new_app_with_stack_and_platrepo('test/fixtures/composer/basic_lock_oldv1').deploy do |app|
				expect(app.output).to match(/- composer \(1/)
				expect(app.output).to match(/Composer version 1/)
			end
		end
	end
	context "with a composer.lock generatead by a late version 1 of Composer" do
		it "builds using Composer 1.x" do
			new_app_with_stack_and_platrepo('test/fixtures/composer/basic_lock_v1').deploy do |app|
				expect(app.output).to match(/- composer \(1/)
				expect(app.output).to match(/Composer version 1/)
			end
		end
	end
	context "with a composer.lock generatead by version 2 of Composer" do
		it "builds using Composer 2.x" do
			new_app_with_stack_and_platrepo('test/fixtures/composer/basic_lock_v2').deploy do |app|
				expect(app.output).to match(/- composer \(2/)
				expect(app.output).to match(/Composer version 2/)
			end
		end
	end
	context "with a malformed COMPOSER_AUTH env var" do
		it "the app still boots" do
			['v1', 'v2'].each do |cv|
				new_app_with_stack_and_platrepo("test/fixtures/composer/basic_lock_#{cv}", run_multi: true).deploy do |app|
					['heroku-php-apache2', 'heroku-php-nginx'].each do |script|
						out = app.run("#{script} -F composer.lock", :heroku => {:env => "COMPOSER_AUTH=malformed"}) # prevent FPM from starting up using an invalid config, that way we don't have to wrap the server start in a `timeout` call
						expect(out).to match(/Starting php-fpm/) # we got far enough (until FPM spits out an error)
					end
				end
			end
		end
	end
end
