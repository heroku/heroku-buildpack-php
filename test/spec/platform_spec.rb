require "ansi/core"
require "json"
require "open3"
require "shellwords"
require "tempfile"

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
	
	describe "Composer Plugin" do
		before(:all) do
			@install_tmpdir = Dir.mktmpdir(nil, generator_fixtures_subdir) # this needs to be on the same level as the source fixture so the relative path references to the installer plugin inside composer.json work
			@export_tmpfile = Tempfile.new("export")
			@profiled_tmpdir = Dir.mktmpdir("profile.d")
			FileUtils.cp("#{generator_fixtures_subdir}/base/expected_platform_composer.json", "#{@install_tmpdir}/composer.json")
			Dir.chdir(@install_tmpdir) do
				cmd = "export_file_path=#{@export_tmpfile.path} profile_dir_path=#{@profiled_tmpdir} composer install --no-dev"
				@stdout, @stderr, @status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
			end
		end
		
		after(:all) do
			FileUtils.remove_entry(@install_tmpdir)
			FileUtils.remove_entry(@profiled_tmpdir)
			@export_tmpfile.unlink
		end
		
		it "performs an installation successfully" do
			expect(@status.exitstatus).to eq(0), "composer install failed, stderr: #{@stderr}, stdout: #{@stdout}"
		end
		
		it "installs multiple packages into the same directory structure" do
			Dir.chdir(@install_tmpdir) do
				expect(File.exist?("bin/php")).to eq(true)
				expect(File.exist?("bin/composer")).to eq(true)
				expect(File.exist?("sbin/httpd")).to eq(true)
				expect(File.exist?("sbin/nginx")).to eq(true)
			end
		end
		
		it "writes an export script" do
			expect(@export_tmpfile.size).to be > 0
		end
		
		it "writes profile scripts so they get sourced in the order of package installs" do
			# fetch all profile.d files and sort them (Bash on startup globs them in alnum sort order, but Ruby's Dir has no guaranteed order)
			profiledscripts = Dir.each_child(@profiled_tmpdir).sort
			# remember from installer output if PHP was installed first or Composer
			order_to_check = @stderr.index("Installing heroku-sys/php ") > @stderr.index("Installing heroku-sys/composer ")
			# now expect the same order in `.profile.d/` for the two packages' scripts
			expect(profiledscripts.index {|f| f.include?("php.sh")} > profiledscripts.index {|f| f.include?("php.sh")}).to eq(order_to_check)
		end
		
		it "writes extension configs so they get loaded in the order of package installs" do
			# fetch all extension INI files and sort them (PHP reads them in alnum sort order on startup, but Ruby's Dir has no guaranteed order)
			extensionconfigs = Dir.each_child("#{@install_tmpdir}/etc/php/conf.d").sort
			# remember from installer outout if ext-blackfire was installed first or ext-redis
			order_to_check = @stderr.index("Installing heroku-sys/ext-blackfire ") > @stderr.index("Installing heroku-sys/ext-redis ")
			# now expect the same order in `conf.d/` for the two extensions' configs
			expect(extensionconfigs.index {|f| f.include?("ext-blackfire.ini")} > extensionconfigs.index {|f| f.include?("ext-redis.ini")}).to eq(order_to_check)
		end
		
		it "enables shared extensions bundled with PHP if necessary" do
			expect(@stderr).to match("Enabling heroku-sys/ext-mbstring")
			expect(Dir.entries("#{@install_tmpdir}/etc/php/conf.d").any? {|f| f.include?("ext-mbstring.ini")}).to eq(true)
		end
	end
end
