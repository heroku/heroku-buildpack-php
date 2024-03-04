require_relative "spec_helper"

describe "A PHP application" do
	context "like the Heroku Getting Started guide example for PHP" do
		it "deploys and works" do
			new_app_with_stack_and_platrepo("php-getting-started").deploy do |app|
				expect(successful_body(app))
			end
		end
	end

	context "with just an index.php" do
		let(:app) {
			new_app_with_stack_and_platrepo('test/fixtures/default')
		}
		it "picks a default version from the expected series" do
			app.deploy do |app|
				series = expected_default_php(ENV["STACK"])
				expect(app.output).to match(/- php \(#{Regexp.escape(series)}\./)
				retry_until retry: 3, sleep: 5 do
					expect(app.run('php -v')).to match(/#{Regexp.escape(series)}\./)
				end
			end
		end
		# FIXME re-use deploy
		it "serves traffic" do
			app.deploy do |app|
				expect(successful_body(app))
			end
		end
		
		it "has Composer defaults set" do
			app.deploy do |app|
				retry_until retry: 3, sleep: 5 do
					composer_envs = app.run('env | grep COMPOSER_')
					expect(composer_envs)
						.to  match(/^COMPOSER_MEMORY_LIMIT=536870912$/)
						.and match(/^COMPOSER_MIRROR_PATH_REPOS=1$/)
						.and match(/^COMPOSER_NO_INTERACTION=1$/)
						.and match(/^COMPOSER_PROCESS_TIMEOUT=0$/)
				end
			end
		end
	end
end
