require_relative "spec_helper"

shared_examples "A PHP application with a composer.json" do |series|
	context "requiring PHP #{series}" do
		let(:app) {
			Hatchet::Runner.new('test/fixtures/default', stack: ENV["STACK"],
				before_deploy: -> { system("composer require --quiet --no-update php '#{series}.*' && composer update --quiet --ignore-platform-reqs") or raise "Failed to require PHP version" }
			)
		}
		it "picks a version from the desired series" do
			app.deploy do |app|
				expect(app.output).to match(/- php \(#{Regexp.escape(series)}\./)
				expect(app.run('php -v')).to match(/#{Regexp.escape(series)}\./)
			end
		end
	end
end
