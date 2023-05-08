require_relative "spec_helper"

describe "A PHP application" do
	it "allows access to /.well-known/ with Apache HTTPD" do
		new_app_with_stack_and_platrepo('test/fixtures/default').tap do |app|
			app.before_deploy(:append) do
				FileUtils.mkdir_p(".well-known/acme")
				File.open(".well-known/acme/foo", "w+") do |f|
					f.write 'bar'
				end
				File.open("Procfile", "w+") do |f|
					f.write 'web: heroku-php-apache2'
				end
			end
			app.deploy do |app|
				expect(successful_body(app, path: '/.well-known/acme/foo')).to eq 'bar'
			end
		end
	end
end
