require_relative "spec_helper"

require "fileutils"
require "json"
require "mkmf"
require "open3"
require "shellwords"

cgroup_fixtures_subdir = "test/fixtures/cgroups"

# what we pass in test cases as an upper limit
MAX_MEMORY = 8*1024*1024*1024*1024
# what Docker sets as memory.limit_in_bytes with cgroupv1 if there is none defined on the container
UNLIMITED_MEMORY = 0x7FFFFFFFFFFFF000 # == 9223372036854771712

# this is a Linux program, so if it is not there, we emulate it with bash functions later to allow testing on e.g. macOS
HAVE_FINDMNT = find_executable("findmnt")

def expected_limit(case_limits)
	["memory.limit_in_bytes", "memory.high", "memory.max", "memory.low"].each do |k|
		next unless case_limits.has_key?(k)
		v = case_limits[k].strip
		return v if v != "max" && v != "0"
	end
	raise "Oops, something is wrong with your test case!"
end

describe "The cgroup helper shell functions" do
	["+e", "-e"].product(["+u", "-u"]).product([true, false]).each do |setopts, verbose|
		context "running in a 'set #{setopts}' Bash instance with verbose=#{verbose}" do
			Dir.each_child(cgroup_fixtures_subdir).reject { |f| not File.directory?("#{cgroup_fixtures_subdir}/#{f}") }.each do |testcase|
				context "for test case #{testcase}" do
					casedir = "#{cgroup_fixtures_subdir}/#{testcase}"
					
					it "produces the expected output" do
						sys_fs_cgroup_files = JSON.parse(File.read("#{casedir}/sys/fs/cgroup/_files.json"))
						
						Dir.mktmpdir do |cgroupfs|
							case_limits = Hash.new("-1")
							
							is_docker_v1_unlimited_case = false
							
							sys_fs_cgroup_files.each do |k,v|
								bn = File.basename(k)
								fn = "#{cgroupfs}#{k}"
								dn = File.dirname(fn)
								FileUtils.mkdir_p(dn)
								File.write(fn, v)
								if bn.start_with?("memory.")
									# this is very crude, as there may be multiple memory. files in different cgroup dirs; for those cases, rely on expected_stdout instead
									case_limits[bn] = v.strip
								end
							end
							
							# unlimited containers in Docker with cgroupsv1 have memory.limit_in_bytes = 9223372036854771712
							is_docker_v1_unlimited_case = (case_limits["memory.limit_in_bytes"].to_i == UNLIMITED_MEMORY)
							
							cmd = "set #{setopts.join(" ")};"
							cmd << "source 'bin/util/cgroups.sh';"
							
							# "emulate" findmnt in case it is missing, e.g. when running these tests on macOS
							if !HAVE_FINDMNT && testcase.include?("v1")
								if testcase.match?(/heroku-(ps-v1-crcompat|cr-v1)/)
									cmd << "findmnt() { return 1; }; export -f findmnt;"
								else
									cmd << "findmnt() { echo '/sys/fs/cgroup/memory'; }; export -f findmnt;"
								end
							elsif !HAVE_FINDMNT
								cmd << "findmnt() { echo '/sys/fs/cgroup'; }; export -f findmnt;"
							end
							
							cmd << "CGROUP_UTIL_PROCFS_ROOT=#{casedir}/proc "
							cmd << "CGROUP_UTIL_CGROUPFS_PREFIX=#{cgroupfs} "
							cmd << "CGROUP_UTIL_VERBOSE=1 " if verbose
							cmd << "cgroup_util_read_cgroup_memory_limit -m #{MAX_MEMORY}"
							
							stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
							
							begin
								expected_status = File.read("#{casedir}/expected_status").to_i
							rescue Errno::ENOENT
								if is_docker_v1_unlimited_case
									# see above - we are expecting a "limit exceeded" here
									expected_status = 99
								elsif testcase.match?(/docker-[^-]+-v2-.+-nores-nolimit/)
									# Docker containers without limit or reservation will not return a limit
									expected_status = 9
								else
									expected_status = 0
								end
							ensure
								expect(status.exitstatus).to eq(expected_status), "cgroups call exited with status #{status.exitstatus}, expected #{expected_status}; stderr: #{stderr}, stdout: #{stdout}"
							end
							
							expect(stderr).not_to include("unbound variable"), "cgroups call contained 'unbound variable' in stderr: #{stderr}, stdout: #{stdout}"
							
							next unless expected_status == 0
							
							begin
								expected_stdout = File.read("#{casedir}/expected_stdout").strip
							rescue Errno::ENOENT
								expected_stdout = expected_limit(case_limits)
							ensure
								expect(stdout.strip).to eq(expected_stdout), "cgroups call was expected to return #{expected_stdout} in stdout but did not; status: #{status.exitstatus}, expected: #{expected_status}, stderr: #{stderr}, stdout: #{stdout}"
							end
							
							unless verbose
								expect(stderr).to be_empty
								next
							end
							
							begin
								# expand %s in file with our tempdir prefix
								expected_stderr = sprintf(File.read("#{casedir}/expected_stderr").strip, cgroupfs)
							rescue Errno::ENOENT
								if is_docker_v1_unlimited_case
									expected_stderr = /Ignoring cgroup memory limit of #{UNLIMITED_MEMORY} Bytes \(exceeds maximum of #{MAX_MEMORY} Bytes\)/
								elsif expected_status == 0
									expected_stderr = /Using limit from/
								else
									expected_stderr = /Reading cgroup v\d limit from/
								end
							ensure
								expect(stderr.strip).to match(expected_stderr), "cgroups call was expected to match #{expected_stderr} in stderr but did not; status: #{status.exitstatus}, expected: #{expected_status}, stderr: #{stderr}, stdout: #{stdout}"
							end
						end
					end
				end
			end
		end
	end
end
