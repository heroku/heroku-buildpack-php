require_relative "spec_helper"

describe "A PHP application on Heroku CI" do
	it "installs dev dependencies" do
		app = new_ci_app_with_stack_and_platrepo('test/fixtures/ci/devdeps')
		app.run_ci do |test_run|
			expect(test_run.output).to match("mockery/mockery")
		end
	end
end
