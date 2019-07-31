require_relative "spec_helper"

describe "A PHP application on Heroku CI" do
	it "installs dev dependencies" do
		app = new_ci_app_with_stack_and_platrepo('test/fixtures/ci/devdeps')
		app.run_ci do |test_run|
			expect(test_run.output).to match("mockery/mockery")
		end
	end
	
	it "has zend.assertions enabled" do
		app = new_ci_app_with_stack_and_platrepo('test/fixtures/ci/zendassert', allow_failure: true)
		app.run_ci do |test_run|
			expect(test_run.status).to eq :failed
			expect(test_run.output).to match("AssertionError")
		end
	end
end
