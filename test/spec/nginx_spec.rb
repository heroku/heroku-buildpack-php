require_relative "spec_helper"

describe "A PHP application" do
	it "installs a recent stable nginx with OpenSSL support and expected modules" do
		new_app_with_stack_and_platrepo('test/fixtures/default').deploy do |app|
			nginx = app.output.match(/- nginx \((\d+\.\d*[02468]\.\d+)/)
			expect(nginx).not_to be_nil, "expected nginx install line in build output"
			expect(Gem::Dependency.new('nginx', '~> 1.14').match?('nginx', nginx[1])).to be == true, "expected nginx version compatible with selector '~> 1.14' but got #{nginx[1]}"
			retry_until retry: 3, sleep: 5 do
				nginx_v = app.run('nginx -V')
				expect(nginx_v).to match(/^built with OpenSSL/)
				expect(nginx_v).to match(/--with-http_auth_request_module/)
				expect(nginx_v).to match(/--with-http_realip_module/)
				expect(nginx_v).to match(/--with-http_ssl_module/)
				expect(nginx_v).to match(/--with-http_stub_status_module/)
			end
		end
	end
	it "allows access to /.well-known/ with Nginx" do
		new_app_with_stack_and_platrepo('test/fixtures/default').tap do |app|
			app.before_deploy(:append) do
				FileUtils.mkdir_p(".well-known/acme")
				File.open(".well-known/acme/foo", "w+") do |f|
					f.write 'bar'
				end
				File.open("Procfile", "w+") do |f|
					f.write 'web: heroku-php-nginx'
				end
			end
			app.deploy do |app|
				expect(successful_body(app, :path => '/.well-known/acme/foo')).to eq 'bar'
			end
		end
	end
end
