require_relative "spec_helper"

describe "A PHP application on Heroku CI" do
	it "installs dev dependencies" do
		app = new_app_with_stack_and_platrepo('test/fixtures/ci/devdeps')
		app.run_ci do |test_run|
			expect(test_run.output).to match("mockery/mockery")
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
	
	context "with Codeception" do
		let(:app) {
			new_app_with_stack_and_platrepo('test/fixtures/ci/codeception')
		}
		it "executes 'codecept run'" do
			app.run_ci do |test_run|
				expect(test_run.output).to match("Codeception found, executing 'codecept run'...")
			end
		end
	end
	
	context "with Behat" do
		let(:app) {
			new_app_with_stack_and_platrepo('test/fixtures/ci/behat')
		}
		it "executes 'behat'" do
			app.run_ci do |test_run|
				expect(test_run.output).to match("Behat found, executing 'behat'...")
			end
		end
	end
	
	context "with PHPSpec" do
		let(:app) {
			new_app_with_stack_and_platrepo('test/fixtures/ci/phpspec')
		}
		it "executes 'phpspec run'" do
			app.run_ci do |test_run|
				expect(test_run.output).to match("PHPSpec found, executing 'phpspec run'...")
			end
		end
	end
	
	context "with atoum" do
		let(:app) {
			new_app_with_stack_and_platrepo('test/fixtures/ci/atoum')
		}
		it "executes 'atoum'" do
			app.run_ci do |test_run|
				expect(test_run.output).to match("atoum found, executing 'atoum'...")
			end
		end
	end
	
	context "with Kahlan" do
		let(:app) {
			new_app_with_stack_and_platrepo('test/fixtures/ci/kahlan')
		}
		it "executes 'kahlan'" do
			app.run_ci do |test_run|
				expect(test_run.output).to match("Kahlan found, executing 'kahlan'...")
			end
		end
	end

	context "with Peridot" do
		let(:app) {
			new_app_with_stack_and_platrepo('test/fixtures/ci/peridot', allow_failure: true)
		}
		it "executes 'peridot'" do
			app.run_ci do |test_run|
				expect(test_run.output).to match("Peridot found, executing 'peridot'...")
				expect(test_run.status).to eq :failed # we want to ensure assert() works, that needs zend.assertions=1
				expect(test_run.output).to match("expected Hello World")
			end
		end
	end
	
	context "with PHPUnit" do
		let(:app) {
			new_app_with_stack_and_platrepo('test/fixtures/ci/phpunit')
		}
		it "executes 'phpunit'" do
			app.run_ci do |test_run|
				expect(test_run.output).to match("PHPUnit found, executing 'phpunit'...")
			end
		end
	end
end
