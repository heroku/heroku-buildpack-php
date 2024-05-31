require_relative "spec_helper"

require "ansi/core"
require "json"
require "open3"
require "shellwords"
require "tempfile"

generator_fixtures_subdir = "test/fixtures/platform/generator"
manifest_fixtures_subdir = "test/fixtures/platform/builder/manifest"
mkrepo_fixtures_subdir = "test/fixtures/platform/builder/mkrepo"
sync_fixtures_subdir = "test/fixtures/platform/builder/sync"

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
					cmd << " php #{bp_root}/bin/util/platform.php"
					args = ""
					begin
						args = File.read("ARGS") # any additional args (other repos)
						cmd << " --list-repositories"
					rescue Errno::ENOENT
					end
					cmd << " #{bp_root}/support/installer "
					cmd << " https://lang-php.s3.us-east-1.amazonaws.com/dist-heroku-20-stable/packages.json " # our default repo
					cmd << args
					
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
					
					break unless ["base", "blackfire-cli", "complex", "composer1", "composer2.0", "composer2.1", "composer2.2", "composer2.3", "defaultphp", "mongo-php-adapter", "provided-ext-bcmath", "symfony-polyfill"].include?(testcase)
					
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
		it "can hold packages compatible with future versions of the buildpack the current version will ignore" do
			Dir.chdir("test/fixtures/platform/repository/futurepaks") do |cwd|
				cmd = "composer install --dry-run"
				stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
				expect(status.exitstatus).to eq(0), "dry run install failed, stderr: #{stderr}, stdout: #{stdout}"
				
				expect(stderr).to include("heroku-sys/php (8.0.8)")
				expect(stderr).not_to include("heroku-sys/ext-gmp")
			end
		end
		
		it "combined with a custom repository installs packages from that repo according to the priority given" do
			Dir.chdir("test/fixtures/platform/repository/priorities") do |cwd|
				Dir.glob("composer-*.json") do |testcase|
					cmd = "COMPOSER=#{testcase} composer install --dry-run"
					stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
					expect(status.exitstatus).to eq(0), "dry run install failed for case #{testcase}, stderr: #{stderr}, stdout: #{stdout}"
					
					expect(stderr).to include("heroku-sys/php (8.0.8)")
					expect(stderr).to include("heroku-sys/ext-igbinary (3.2.7)")
					if ["composer-default.json"].include? testcase
						expect(stderr).to include("heroku-sys/ext-redis (5.3.4)") # packages from the custom repo (listed first) are authoritative; the newer package version from the default repo is not selected
					else
						expect(stderr).to include("heroku-sys/ext-redis (5.3.5)") # canonical=false or an appropriate only/exclude setting on the custom repo means the newer version from the default repo is selected
					end
				end
			end
		end
	end
	
	describe "Package Manifest Generator Script" do
		Dir.each_child(manifest_fixtures_subdir) do |testcase|
			it "produces the expected package manifest JSON for case #{testcase}" do
				bp_root = [".."].cycle("#{manifest_fixtures_subdir}/#{testcase}".count("/")+1).to_a.join("/") # right "../.." sequence to get us back to the root of the buildpack
				Dir.chdir("#{manifest_fixtures_subdir}/#{testcase}") do |cwd|
					cmd = File.read("ENV") # any env vars for the test (manifest.py needs STACK, S3_BUCKET, S3_PREFIX, TIME)
					cmd << " python3 #{bp_root}/support/build/_util/include/manifest.py "
					cmd << File.read("ARGS")
					stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
				
					expect(status.exitstatus).to eq(0), "manifest.py failed, stdout: #{stdout}, stderr: #{stderr}"
				
					expected_json = JSON.parse(File.read("expected_manifest.json"))
					generated_json = JSON.parse(stdout)
				
					expect(expected_json).to eq(generated_json)
				end
			end
		end
	end
	
	describe "Repository Generator Script" do
		Dir.each_child(mkrepo_fixtures_subdir) do |testcase|
			it "produces the expected platform packages.json for case #{testcase}" do
				bp_root = [".."].cycle("#{mkrepo_fixtures_subdir}/#{testcase}".count("/")+1).to_a.join("/") # right "../.." sequence to get us back to the root of the buildpack
				Dir.chdir("#{mkrepo_fixtures_subdir}/#{testcase}") do |cwd|
					
					cmd = "S3_BUCKET=OURS3BUCKET S3_PREFIX=OURS3PREFIX/ #{bp_root}/support/build/_util/mkrepo.sh *.composer.json"
					stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
				
					expect(status.exitstatus).to eq(0), "mkrepo.sh failed, stdout: #{stdout}, stderr: #{stderr}"
				
					expected_json = JSON.parse(File.read("expected_packages.json"))
					generated_json = JSON.parse(stdout)
				
					expect(expected_json).to eq(generated_json)
				end
			end
		end
	end
	
	describe "Repository Sync Operations Program", :focused => true do
		it "produces the expected list of operations when syncing between two repositories" do
			bp_root = [".."].cycle("#{sync_fixtures_subdir}".count("/")+1).to_a.join("/") # right "../.." sequence to get us back to the root of the buildpack
			Dir.chdir("#{sync_fixtures_subdir}") do |cwd|
				cmd = "python3 #{bp_root}/support/build/_util/include/sync.py --dry-run us-east-1 lang-php dist-heroku-24-develop/ manifests-src/ us-east-1 lang-php dist-heroku-24-stable/ manifests-dst/"
				stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
				
				expect(status.exitstatus).to eq(0), "sync.py failed, stdout: #{stdout}, stderr: #{stderr}"
				
				expected_json = JSON.parse(File.read("expected_ops.json"))
				generated_json = JSON.parse(stdout)
				
				# compare sorted list of operations (sync.py processes in no defined order)
				expect(expected_json.sort_by(&:zip)).to eq(generated_json.sort_by(&:zip))
			end
		end
	end
	
	describe "during a build" do
		context "of a project that has invalid platform dependencies" do
			let(:app) {
				new_app_with_stack_and_platrepo('test/fixtures/default',
					before_deploy: -> { system("composer require --quiet --ignore-platform-reqs php '99.*'") or raise "Failed to require PHP version" },
					run_multi: true,
					allow_failure: true
				)
			}
			it "fails the build" do
				app.deploy do |app|
					expect(app.output).to include("ERROR: Failed to install system packages!")
				end
			end
		end
		
		context "of a project that uses polyfills providing both bundled-with-PHP and third-party extensions" do
			# we set an invalid COMPOSER_AUTH on all of these to stop and fail the build on userland dependency install
			# we only need to check what happened during the platform install step, so that speeds things up
			it "treats polyfills for bundled-with-PHP and third-party extensions the same", :requires_php_on_stack => "7.4" do
				new_app_with_stack_and_platrepo('test/fixtures/platform/installer/polyfills', config: { "COMPOSER_AUTH" => "broken" }, allow_failure: true).deploy do |app|
					expect(app.output).to include("detected userland polyfill packages for PHP extensions")
					expect(app.output).not_to include("- ext-mbstring") # ext not required by any dependency, so should not be installed or even attempted ("- ext-mbstring...")
					out_before_polyfills, out_after_polyfills = app.output.split("detected userland polyfill packages for PHP extensions", 2)
					expect(out_before_polyfills).to include("- php (7.4")
					expect(out_after_polyfills).to include("- ext-ctype (already enabled)")
					expect(out_after_polyfills).to include("- ext-raphf (") # ext-pq, which we required, depends on it
					expect(out_after_polyfills).to include("- ext-pq (")
					expect(out_after_polyfills).to include("- ext-uuid (")
					expect(out_after_polyfills).to include("- ext-xmlrpc (bundled with php)")
				end
			end
			it "installs native bundled extensions for legacy PHP builds for installer < 1.6 even if they are provided by a polyfill", :requires_php_on_stack => "7.3" do
				new_app_with_stack_and_platrepo('test/fixtures/platform/installer/polyfills-legacy', config: { "COMPOSER_AUTH" => "broken" }, allow_failure: true).deploy do |app|
					expect(app.output).to include("detected userland polyfill packages for PHP extensions")
					expect(app.output).not_to include("- ext-mbstring") # ext not required by any dependency, so should not be installed or even attempted ("- ext-mbstring...")
					out_before_polyfills, out_after_polyfills = app.output.split("detected userland polyfill packages for PHP extensions", 2)
					expect(out_before_polyfills).to include("- php (7.3")
					expect(out_before_polyfills).to include("- ext-xmlrpc (")
					expect(out_after_polyfills).to include("- ext-raphf (") # ext-pq, which we required, depends on it
					expect(out_after_polyfills).to include("- ext-pq (")
					expect(out_after_polyfills).to include("- ext-uuid (")
				end
			end
			it "solves using the polyfills first and does not downgrade installed packages in the later native install step" do
				new_app_with_stack_and_platrepo('test/fixtures/platform/installer/polyfills-nodowngrade', config: { "COMPOSER_AUTH" => "broken" }, allow_failure: true).deploy do |app|
					expect(app.output).to include("detected userland polyfill packages for PHP extensions")
					expect(app.output).not_to include("- ext-mbstring") # ext not required by any dependency, so should not be installed or even attempted ("- ext-mbstring...")
					out_before_polyfills, out_after_polyfills = app.output.split("detected userland polyfill packages for PHP extensions", 2)
					expect(out_before_polyfills).to include("- php (8")
					expect(out_after_polyfills).to include("- ext-ctype (already enabled)")
					expect(out_after_polyfills).to include("- ext-raphf (") # ext-pq, which we required, depends on it
					expect(out_after_polyfills).to include("- ext-pq (")
					expect(out_after_polyfills).to include("- ext-uuid (")
					expect(out_after_polyfills).not_to include("- ext-xmlrpc (")
					expect(out_after_polyfills).to include("no suitable native version of ext-xmlrpc available")
				end
			end
			it "ignores a polyfill for an extension that another extension depends upon" do
				new_app_with_stack_and_platrepo('test/fixtures/platform/installer/polyfills-nointernaldeps', config: { "COMPOSER_AUTH" => "broken" }, allow_failure: true).deploy do |app|
					expect(app.output).to include("detected userland polyfill packages for PHP extensions")
					# ext-pq got installed...
					expect(app.output).to include("- ext-pq (")
					out_before_pq, out_after_pq = app.output.split("- ext-pq (", 2)
					# ... which immediately had raphf.native as a dependency...
					expect(out_before_pq).to include("- ext-raphf (")
					# ... so the subsequent polyfill "override" attempt is a no-op
					expect(out_after_pq).to include("- ext-raphf (already enabled)")
				end
			end
		end
	end
end
