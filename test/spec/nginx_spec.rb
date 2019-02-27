require_relative "spec_helper"

describe "A PHP application" do
	let(:app) {
		new_app_with_stack_and_platrepo('test/fixtures/default')
	}
	it "installs nginx with OpenSSL support" do
		app.deploy do |app|
			expect(app.output).to match(/- nginx \((\d+\.\d+\.\d+)/)
			expect(app.run('nginx -V')).to match(/^built with OpenSSL/)
		end
	end
end
