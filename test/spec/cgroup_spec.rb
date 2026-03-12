require_relative "spec_helper"

require "fileutils"
require "json"
require "mkmf"
require "open3"
require "shellwords"

cgroup_fixtures_subdir = "test/fixtures/cgroups"

# this is a Linux program, so if it is not there, we emulate it with bash functions later to allow testing on e.g. macOS
HAVE_FINDMNT = find_executable("findmnt")

describe "The cgroup helper shell functions" do
	["+e", "-e"].product(["+u", "-u"]).product([true, false], ['', '_with_fallback']).each do |setopts, verbose, with_fallback_fn_suffix|
		func = "cgroup_util_find_cgroup2_memory_limit#{with_fallback_fn_suffix}"
		context "running '#{func}' in a 'set #{setopts}' Bash instance with verbose=#{verbose}" do
			Dir.each_child(cgroup_fixtures_subdir).reject { |f| not File.directory?("#{cgroup_fixtures_subdir}/#{f}") }.each do |testcase|
				context "for test case #{testcase}" do
					casedir = "#{cgroup_fixtures_subdir}/#{testcase}"
					
					it "produces the expected output" do
						case_has_procfs = File.exist?("#{casedir}/proc/self/mountinfo")
						begin
							sys_fs_cgroup_files = JSON.parse(File.read("#{casedir}/sys/fs/cgroup/_files.json"))
						rescue Errno::ENOENT
							sys_fs_cgroup_files = {}
						end
						
						Dir.mktmpdir do |cgroupfs|
							case_limits = Hash.new("-1")
							
							sys_fs_cgroup_files.each do |k,v|
								bn = File.basename(k)
								fn = "#{cgroupfs}#{k}"
								dn = File.dirname(fn)
								FileUtils.mkdir_p(dn)
								File.write(fn, v)
							end
							
							cmd = "set #{setopts.join(" ")};"
							cmd << "source 'bin/util/cgroups.sh';"
							
							if !HAVE_FINDMNT || !case_has_procfs
								if case_has_procfs
									# "emulate" findmnt in case it is missing, e.g. when running these tests on macOS
									# example mountinfo line we want to extract the target path from:
									# 194 193 0:31 / /sys/fs/cgroup ro,nosuid,nodev,noexec,relatime - cgroup2 cgroup rw
									cmd << 'findmnt() { set -o pipefail; local opt OPTARG OPTIND=1 type file; while getopts ":-:o:t:F:" opt; do if [[ "$opt" == "t" ]]; then type=$OPTARG; elif [[ "$opt" == "F" ]]; then file=$OPTARG; fi; done; grep -- " ${type} " "$file" | cut -d" " -f5; }; export -f findmnt;'
								else
									# without a procfs, the case will never get far enough, so we can return the desired status 1 if the requested fs is 'proc'
									# we want this for HAVE_FINDMNT==true as well, otherwise it would succeed on Linux since the system 'findmnt' returns something
									cmd << 'findmnt() { if grep -q -- "-t proc" <<<"$@"; then return 1; fi; echo "/doesnotmatter"; }; export -f findmnt;'
								end
							end
							
							cmd << "CGROUP_UTIL_PROCFS_ROOT=#{casedir}/proc " if case_has_procfs
							cmd << "CGROUP_UTIL_CGROUPFS_PREFIX=#{cgroupfs} "
							cmd << "CGROUP_UTIL_VERBOSE=1 " if verbose
							cmd << func
							
							stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
							
							begin
								expected_status = File.read("#{casedir}/expected_status#{with_fallback_fn_suffix}").to_i
							rescue Errno::ENOENT
								expected_status = 0
							ensure
								expect(status.exitstatus).to eq(expected_status), "cgroups call exited with status #{status.exitstatus}, expected #{expected_status}; stderr: #{stderr}, stdout: #{stdout}"
							end
							
							expect(stderr).not_to include("unbound variable"), "cgroups call contained 'unbound variable' in stderr: #{stderr}, stdout: #{stdout}"
							
							unless verbose
								expect(stderr).to be_empty
								next
							end
							
							begin
								# expand %1$s in file with our tempdir prefix and %2$s with the casedir prefix
								expected_stderr = sprintf(File.read("#{casedir}/expected_stderr#{with_fallback_fn_suffix}").strip, cgroupfs, casedir)
							rescue Errno::ENOENT
								expected_stderr = /Reading cgroup2 memory limits from/
							ensure
								expect(stderr.strip).to match(expected_stderr), "cgroups call was expected to match #{expected_stderr} in stderr but did not; status: #{status.exitstatus}, expected: #{expected_status}, stderr: #{stderr}, stdout: #{stdout}"
							end

							next unless expected_status == 0
							
							expected_stdout_filename = "#{casedir}/expected_stdout#{with_fallback_fn_suffix}"
							expected_stdout_filename_fallback = "#{casedir}/expected_stdout"
							begin
								expected_stdout = File.read(expected_stdout_filename).strip
							rescue Errno::ENOENT
								# fall back to "regular case" output, it's the same for most test cases
								if expected_stdout_filename != expected_stdout_filename_fallback
									expected_stdout_filename = expected_stdout_filename_fallback
									retry
								end
								raise
							ensure
								expect(stdout.strip).to eq(expected_stdout), "cgroups call was expected to return #{expected_stdout} in stdout but did not; status: #{status.exitstatus}, expected: #{expected_status}, stderr: #{stderr}, stdout: #{stdout}"
							end
						end
					end
				end
			end
		end
	end
end
