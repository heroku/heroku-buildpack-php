require_relative "spec_helper"

describe "A PHP application" do
	context "with just an index.php" do
		let(:app) {
			new_app_with_stack_and_platrepo('test/fixtures/default')
		}
		it "picks a default version from the expected series" do
			app.deploy do |app|
				series = expected_default_php(ENV["STACK"])
				expect(app.output).to match(/- php \(#{Regexp.escape(series)}\./)
				expect(app.run('php -v')).to match(/#{Regexp.escape(series)}\./)
			end
		end
		# FIXME re-use deploy
		it "serves traffic" do
			app.deploy do |app|
				expect(successful_body(app))
			end
		end
	end
end
