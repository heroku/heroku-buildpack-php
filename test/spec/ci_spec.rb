require_relative "spec_helper"

describe "A PHP application on Heroku CI" do
	it "installs dev dependencies and caches them" do
		app = new_app_with_stack_and_platrepo('test/fixtures/ci/devdeps')
		app.run_ci do |test_run|
			expect(test_run.output).to match("mockery/mockery")
			expect(test_run.output).to include("Downloading")
			test_run.run_again
			expect(test_run.output).to_not include("Downloading")
		end
	end
	
	it "has zend.assertions enabled" do
		app = new_app_with_stack_and_platrepo('test/fixtures/ci/zendassert', allow_failure: true)
		app.run_ci do |test_run|
			expect(test_run.status).to eq :failed
			expect(test_run.output).to match("AssertionError")
		end
	end
	
	it "fails to auto-run tests if nothing suitable is found" do
		app = new_app_with_stack_and_platrepo('test/fixtures/default', allow_failure: true)
		app.run_ci do |test_run|
			expect(test_run.status).to eq :failed
			expect(test_run.output).to match("No tests found.")
		end
	end
	
	context "specifying a composer.json 'test' script entry" do
		let(:app) {
			new_app_with_stack_and_platrepo('test/fixtures/ci/composertest')
		}
		it "executes 'composer test'" do
			app.run_ci do |test_run|
				expect(test_run.output).to match("Script 'composer test' found, executing...")
			end
		end
	end
end
