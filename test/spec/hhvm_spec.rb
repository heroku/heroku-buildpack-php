require_relative "spec_helper"

describe "An HHVM application", :stack => "cedar-14" do
	it "builds and boots" do
		app = new_app_with_stack_and_platrepo('test/fixtures/default',
			before_deploy: -> { system("composer require --quiet --ignore-platform-reqs 'hhvm:*'") or raise "Failed to require HHVM" }
		)
		app.deploy do |app|
			expect(app.output).to match("- hhvm")
			expect(successful_body(app))
		end
	end
end
