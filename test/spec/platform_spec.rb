require "ansi/core"
require "json"
require "open3"
require "shellwords"
require "tempfile"

generator_fixtures_subdir = "test/fixtures/platform/generator"

describe "The PHP Platform Installer" do
	describe "composer.json Generator Script" do
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
						expect(status.exitstatus).to eq(expected_status), "platform.php exited with status #{status.exitstatus}, expected #{expected_status}; stderr: #{stderr}, stdout: #{stdout}"
					end
					
					begin
						expected_stderr = File.read("expected_stderr")
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
					
					break unless ["base", "blackfire-cli", "complex", "defaultphp", "mongo-php-adapter"].include?(testcase)
					
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
	
	describe "Repository" do
		after(:each) do
			Process.kill("TERM", @pid)
			Process.wait(@pid)
		end
		
		it "can hold packages compatible with future versions of the buildpack the current version will ignore" do
			Dir.chdir("test/fixtures/platform/repository/bundledextpacks") do |cwd|
				# we spawn a web server that serves packages.json, like a real composer repository
				# this is to ensure that Composer really uses ComposerRepository behavior for provide/replace declarations
				@pid = spawn("php -S localhost:8080")
				
				cmd = "composer install --dry-run"
				stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
				expect(status.exitstatus).to eq(0), "dry run install failed, stderr: #{stderr}, stdout: #{stdout}"
				
				expect(stderr).to include("heroku-sys/php (8.0.8)")
				expect(stderr).not_to include("heroku-sys/ext-gmp")
			end
		end
	end
	
	describe "Repository Generator Script" do
		it "orders PHP extensions in descending PHP version requirement order" do
			# our PHP packages are named "php", and versioned "7.4.0", "8.0.9", and so forth
			# each extension, say "ext-redis", has a release version, say "5.1.2", but gets compiled for each PHP version series
			# as a result, there are multiple packages named "ext-redis" with version "5.1.2", pointing to different tarballs
			# each of these packages' Composer package metadata lists the respective PHP version series as a dependency in its "require" section, e.g. "php": "8.0.*" or "php": "7.4.*"
			# Composer's dependency solver supports multiple packages with the same name and version inside a repository, but to keep complexity manageable, it will pick the first packages that satisfy the given version range requirements, and "stick" to them, even if for some selected packages, a different combination with higher version numbers might be resolvable
			# this is never a problem in "real life" for user-land dependencies, because no package there can exist multiple times with the same name and version, but different requirements inside
			# we do however need this for extensions, and if a user's requirements have no specific bounds (e.g. the user requires "php":">=7.0.0" and "ext-redis":"*"), and edge case might be triggered
			# in this particular situation, a user would get PHP 8 and ext-redis
			# however, if a user lists "ext-redis":"*" first, and "php":">=7.0.0" second, and the repository lists the "ext-redis" package for PHP 7.4.* before the "ext-redis" package for PHP 8.0.*, a user will get PHP 7.4 installed instead of PHP 8.0
			# if the repository however lists the "ext-redis" package for PHP 8.0.* first, a user will get PHP 8.0 installed instead
			# that's why mkrepo.sh re-orders extension packages to be in descending order of PHP series they are compiled for, to ensure that users always get the highest possible PHP version that also satisfies all other requirements
			
			Dir.chdir("test/fixtures/platform/builder/mkrepo/order-exts-desc") do
				# shell glob expansion means mkrepo.sh will receive the file arguments in alnum order, so our PHP 7.4 extension package metadata file will be handed in before the PHP 8.0 extension one
				cmd = "../../../../../../support/build/_util/mkrepo.sh OURS3BUCKET OURS3PREFIX/ *.composer.json"
				stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
				
				expect(status.exitstatus).to eq(0), "mkrepo.sh failed, stdout: #{stdout}, stderr: #{stderr}"
				
				expected_json = JSON.parse(File.read("expected_packages.json"))
				generated_json = JSON.parse(stdout)
				
				# our expected packages.json has the PHP 8.0.* extension before the PHP 7.4.* extension, do they match?
				expect(expected_json).to eq(generated_json)
			end
		end
	end
	
	describe "handling edge case" do
		describe "provided ext-bcmath" do
			it "does not install" do
				# this extension is declared "replace"d by package "php", and thus conflicts in Composer 1
				Dir.chdir("#{generator_fixtures_subdir}/provided-ext-bcmath") do |cwd|
					cmd = "COMPOSER=expected_platform_composer.json composer install --dry-run"
					stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
					expect(status.exitstatus).not_to eq(0), "dry run install succeeded unexpectedly; stderr: #{stderr}, stdout: #{stdout}"
				end
			end
		end
	end
end
