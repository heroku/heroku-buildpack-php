require_relative "spec_helper"

describe "A PHP application" do
	let(:app) {
		new_app_with_stack_and_platrepo('test/fixtures/default')
	}
	it "installs a recent stable nginx with OpenSSL support and expected modules" do
		app.deploy do |app|
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
end
