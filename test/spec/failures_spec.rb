require_relative "spec_helper"

describe "A PHP application failing to build" do
	context "because the composer compile script exits non-zero" do
		before(:all) do
			@app = new_app_with_stack_and_platrepo_and_bin_report_dumper(
				"test/fixtures/composer/compile_script",
				config: {
					"COMPILE_SCRIPT_SLEEP" => 1,
					"COMPILE_SCRIPT_EXIT" => 1,
				},
				allow_failure: true,
			)
			@app.deploy
		end
		
		after(:all) do
			@app.teardown!
		end
		
		it "throws an error" do
			expect(@app.output).to include("Compile step failed!")
		end
		
		it "captures information about the build" do
			expect(@app.bin_report_dump).to match(
				"bootstrap.duration" => a_kind_of(Float),
				"platform.prepare.duration" => a_kind_of(Float),
				"platform.install.main.packages.installed_count" => 4,
				"platform.install.main.duration" => a_kind_of(Float),
				"platform.polyfill_count" => 0,
				"platform.packages.installed_count" => 4,
				"platform.php.version" => a_string_matching(/^\d+\.\d+\.\d+$/),
				"platform.php.series" => a_string_matching(/^\d+\.\d+$/),
				"platform.install.duration" => a_kind_of(Float),
				"dependencies.install.duration" => a_kind_of(Float),
				"dependencies.packages.installed_count" => 0,
				"failure_reason" => "scripts.compile",
				"open_timers" => "__main__,scripts.compile",
				"duration" => a_kind_of(Float),
				"scripts.compile.duration" => a_kind_of(Float).and(a_value > 1),
				"open_timers" => "__main__,scripts.compile",
				"duration" => a_kind_of(Float),
				"scripts.compile.duration" => a_kind_of(Float).and(a_value > 1),
			)
		end
	end
	
	context "because composer.json is malformed" do
		let(:lint_errmsg) { "Expecting property name enclosed in double quotes: line 3 column 5 (char 17)" }
		before(:all) do
			@app = new_app_with_stack_and_platrepo_and_bin_report_dumper(
				"test/fixtures/platform/generator/base",
				allow_failure: true,
				before_deploy: -> {
					File.open("composer.json", "w+") do |f|
						f.write <<~EOF
						{
						  "foo": {
						    false
						  }
						}
						EOF
					end
				}
			)
			@app.deploy
		end
		
		after(:all) do
			@app.teardown!
		end
		
		it "throws an error" do
			expect(@app.output).to include("Basic validation for 'composer.json' failed!")
			expect(@app.output).to include("> #{lint_errmsg}")
		end
		
		it "captures information about the build" do
			expect(@app.bin_report_dump).to match(
				"failure_reason" => "composer_json.lint",
				"failure_detail" => lint_errmsg,
				"open_timers" => "__main__",
				"duration" => a_kind_of(Float),
			)
		end
	end
	
	context "because composer.lock is malformed" do
		let(:lint_errmsg) { "Expecting property name enclosed in double quotes: line 3 column 5 (char 17)" }
		before(:all) do
			@app = new_app_with_stack_and_platrepo_and_bin_report_dumper(
				"test/fixtures/platform/generator/base",
				allow_failure: true,
				before_deploy: -> {
					File.open("composer.lock", "w+") do |f|
						f.write <<~EOF
						{
						  "foo": {
						    false
						  }
						}
						EOF
					end
				}
			)
			@app.deploy
		end
		
		after(:all) do
			@app.teardown!
		end
		
		it "throws an error" do
			expect(@app.output).to include("Failed to parse 'composer.lock'!")
			expect(@app.output).to include("> #{lint_errmsg}")
		end
		
		it "captures information about the build" do
			expect(@app.bin_report_dump).to match(
				"failure_reason" => "composer_lock.lint",
				"failure_detail" => lint_errmsg,
				"open_timers" => "__main__",
				"duration" => a_kind_of(Float),
			)
		end
	end
end
