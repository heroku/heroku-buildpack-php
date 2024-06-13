require_relative "spec_helper"

require "open3"
require "shellwords"
require "time"

devcenter_fixtures_subdir = "test/fixtures/devcenter"
devcenter_tooling_subdir = "support/devcenter"

describe "The Dev Center support tooling" do
	before(:all) do
		system("composer install --quiet -d #{devcenter_tooling_subdir}") or raise "Failed to install Dev Center support tooling dependencies"
	end
	
	describe "Changelog generator script" do
		it "produces the expected Markdown" do
			cmd = "cat #{devcenter_fixtures_subdir}/changelog/sync.log | #{devcenter_tooling_subdir}/changelog.php"
			stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
			generated_markdown = stdout
			
			expect(status.exitstatus).to eq(0), "changelog.php exited with status #{status.exitstatus}; stderr: #{stderr}, stdout: #{stdout}"
			
			expected_markdown = File.read("#{devcenter_fixtures_subdir}/changelog/changelog.md")
			# the expected markdown contains "%B %Y" strftime directives at the top
			expected_markdown = Time.now.utc.strftime(expected_markdown)
			expect(expected_markdown).to eq(generated_markdown)
		end
		it "produces a near-empty document if there are no additions" do
			cmd = "cat #{devcenter_fixtures_subdir}/changelog/sync-nothingnew.log | #{devcenter_tooling_subdir}/changelog.php"
			stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
			generated_markdown = stdout
			
			expect(status.exitstatus).to eq(0), "changelog.php exited with status #{status.exitstatus}; stderr: #{stderr}, stdout: #{stdout}"
			
			expected_markdown = File.read("#{devcenter_fixtures_subdir}/changelog/changelog-nothingnew.md")
			# the expected markdown contains "%B %Y" strftime directives at the top
			expected_markdown = Time.now.utc.strftime(expected_markdown)
			expect(expected_markdown).to eq(generated_markdown)
		end
	end
	
	describe "PHP Support article generator script" do
		it "produces the expected Markdown" do
			cmd = "#{devcenter_tooling_subdir}/generate.php -d '2024-02-29T20:24:02.29Z' -p '7.3,7.4,8.0,8.1,8.2' -s '20,22' #{devcenter_fixtures_subdir}/generator/packages.heroku-{20,22}.json"
			stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
			generated_markdown = stdout
			
			expect(status.exitstatus).to eq(0), "generate.php exited with status #{status.exitstatus}; stderr: #{stderr}, stdout: #{stdout}"
			
			expected_markdown = File.read("#{devcenter_fixtures_subdir}/generator/php-support.md")
			expect(expected_markdown).to eq(generated_markdown)
			
			expect(stderr).to include("NOTICE: whitelisted runtime series not found in input: 7.3")
		end
		it "rejects PHP version series that are not whitelisted" do
			cmd = "#{devcenter_tooling_subdir}/generate.php -d '2024-02-29T20:24:02.29Z' -p '7.4,8.0,8.1' -s '20,22' --strict #{devcenter_fixtures_subdir}/generator/packages.heroku-{20,22}.json"
			stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
			generated_markdown = stdout
			
			expect(status.exitstatus).to eq(1), "generate.php exited with status #{status.exitstatus}; stderr: #{stderr}, stdout: #{stdout}"
			
			expect(stderr).to include("WARNING: runtime series ignored in input due to missing whitelist entries: 8.2")
		end
	end
end
