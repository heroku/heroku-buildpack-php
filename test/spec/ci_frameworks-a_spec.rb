require_relative "spec_helper"

describe "A PHP application on Heroku CI" do
	{
		"atoum":       "atoum",
		"Behat":       "behat",
		"Codeception": "codecept run",
	}.each do |name, command|
		context "using the #{name} CI framework" do
			let(:app) {
				new_app_with_stack_and_platrepo("test/fixtures/ci/#{name.downcase}")
			}
			it "automatically executes '#{command}'" do
				app.run_ci do |test_run|
					expect(test_run.output).to match("#{name} found, executing '#{command}'...")
				end
			end
		end
	end
end
