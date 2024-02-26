require_relative "spec_helper"

require "open3"
require "shellwords"
require "time"

devcenter_fixtures_subdir = "test/fixtures/devcenter"
devcenter_tooling_subdir = "support/devcenter"

describe "The Dev Center support tooling" do
	before(:all) do
		system("composer install -n -d #{devcenter_tooling_subdir}") or raise "Failed to install Dev Center support tooling dependencies"
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
end
