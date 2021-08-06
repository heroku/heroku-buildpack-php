require "ansi/core"
require "json"
require "open3"
require "shellwords"

generator_fixtures_subdir = "test/fixtures/platform/generator"

describe "The PHP Platform Installer" do
	describe "Generator Script" do
		Dir.each_child(generator_fixtures_subdir) do |testcase|
			it "produces the expected platform composer.json for case #{testcase}" do
				bp_root = [".."].cycle("#{generator_fixtures_subdir}/#{testcase}".count("/")+1).to_a.join("/") # right "../.." sequence to get us back to the root of the buildpack
				Dir.chdir("#{generator_fixtures_subdir}/#{testcase}") do |cwd|
					cmd = ""
					begin
						cmd << File.read("ENV") # any env vars (e.g. `HEROKU_PHP_INSTALL_DEV=`), or function declarations
					rescue Errno::ENOENT
					end
					cmd << " STACK=heroku-20 " # that's the stack all the tests are written for
					cmd << " php #{bp_root}/bin/util/platform.php #{bp_root}/support/installer "
					cmd << "https://lang-php.s3.amazonaws.com/dist-heroku-20-stable/packages.json " # our default repo
					begin
						cmd << File.read("ARGS") # any additional args (other repos)
					rescue Errno::ENOENT
					end
					
					stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
					
					begin
						expected_status = File.read("expected_status").to_i
					rescue Errno::ENOENT
						expected_status = 0
					ensure
						expect(status.exitstatus).to eq(expected_status), "platform.php failed, stderr: #{stderr}, stdout: #{stdout}"
					end
					
					begin
						expected_stderr = File.read("expected_stderr") # any env vars (e.g. `HEROKU_PHP_INSTALL_DEV=`), or function declarations
						expect(stderr).to eq(expected_stderr)
					rescue Errno::ENOENT
					end
					
					break unless status == 0
					
					expected_json = JSON.parse(File.read("expected_platform_composer.json"))
					generated_json = JSON.parse(stdout)
					
					# check all of the expected keys are there (and only those)
					expect(expected_json.keys).to eq(generated_json.keys)
					
					# validate each key in the generated JSON
					# we have to do this because we want to treat e.g. the "provide" key a bit differently
					generated_json.keys.each do | key |
						if key == "provide"
							# "heroku-sys/heroku" in "provide" has a string like "20.2021.02.28" where "20" is the version from the stack name (like heroku-20) and the rest is a current date string
							expect(generated_json[key].keys).to eq(expected_json[key].keys)
							expect(generated_json[key]).to include(expected_json[key].tap { |h| h.delete("heroku-sys/heroku") })
							expect(generated_json[key]["heroku-sys/heroku"]).to match(/^20/)
						else
							expect(generated_json[key]).to eq(expected_json[key])
						end
					end
					
					break unless ["base", "complex", "blackfire-cli", "defaultphp"].include?(testcase)
					
					# and finally check if it's installable in a dry run
					cmd = "COMPOSER=expected_platform_composer.json composer install --dry-run"
					cmd << " --no-dev" unless testcase == "complex"
					stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
					expect(status.exitstatus).to eq(0), "dry run install failed, stderr: #{stderr}, stdout: #{stdout}"
				end
			end
		end
	end
end
