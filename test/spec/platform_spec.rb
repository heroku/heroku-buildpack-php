require_relative "spec_helper"

require "ansi/core"
require "json"
require "open3"
require "shellwords"
require "tempfile"

generator_fixtures_subdir = "test/fixtures/platform/generator"
manifest_fixtures_subdir = "test/fixtures/platform/builder/manifest"
mkrepo_fixtures_subdir = "test/fixtures/platform/builder/mkrepo"
priorities_fixtures_subdir = "test/fixtures/platform/repository/priorities"
sync_fixtures_subdir = "test/fixtures/platform/builder/sync"

describe "The PHP Platform Installer" do
	describe "composer.json Generator Script" do
		Dir.each_child(generator_fixtures_subdir) do |testcase|
			it "produces the expected platform composer.json for case #{testcase}" do
				bp_root = [".."].cycle("#{generator_fixtures_subdir}/#{testcase}".count("/")+1).to_a.join("/") # right "../.." sequence to get us back to the root of the buildpack
				Dir.chdir("#{generator_fixtures_subdir}/#{testcase}") do |cwd|
					cmd = ""
					is_dev_install = false
					begin
						cmd << File.read("ENV") # any env vars (e.g. `HEROKU_PHP_INSTALL_DEV=`), or function declarations
						is_dev_install = cmd.match?(/\bHEROKU_PHP_INSTALL_DEV=(""|''|$|\s)/) # if it's a dev install (empty HEROKU_PHP_INSTALL_DEV variable)
					rescue Errno::ENOENT
					end
					cmd << " STACK=heroku-24 " # that's the stack all the tests are written for
					cmd << " php #{bp_root}/bin/util/platform.php"
					args = ""
					begin
						args = File.read("ARGS") # any additional args (other repos)
						cmd << " --list-repositories"
					rescue Errno::ENOENT
					end
					cmd << " #{bp_root}/support/installer "
					cmd << " https://lang-php.s3.us-east-1.amazonaws.com/dist-heroku-24-amd64-stable/packages.json " # our default repo
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
							# "heroku-sys/heroku" in "provide" has a string like "24.2025.05.05" where "24" is the version from the stack name (like heroku-24) and the rest is a current date string
							expect(generated_json[key].keys).to eq(expected_json[key].keys)
							expect(generated_json[key]).to include(expected_json[key].tap { |h| h.delete("heroku-sys/heroku") })
							expect(generated_json[key]["heroku-sys/heroku"]).to match(/^24/)
						else
							expect(generated_json[key]).to eq(expected_json[key])
						end
					end
					
					# not all cases are actually installable (e.g. "composer1" is expected to fail since that is EOL; "customrepo" points to a repo URL that does not actually exist)
					break if ["blackfire-cli-unknown", "composer1", "customrepo", "require-dev-runtime-only"].include?(testcase)
					
					# and finally check if it's installable in a dry run
					cmd = "COMPOSER=expected_platform_composer.json composer install --dry-run"
					cmd << " --no-dev" unless is_dev_install
					stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
					expect(status.exitstatus).to eq(0), "dry run install failed, stderr: #{stderr}, stdout: #{stdout}"
				end
			end
		end
	end
	
	describe "Composer Plugin" do
		before(:all) do
			fixture = "test/fixtures/platform/installer/polyfills"
			stack_with_arch = stack = ENV["STACK"] || "heroku-24"
			stack_with_arch = "#{stack}-amd64" unless stack == "heroku-22"
			
			@install_tmpdir = Dir.mktmpdir("install")
			Dir.chdir(fixture) do |cwd|
				bp_root = File.expand_path([".."].cycle(fixture.count("/")+1).to_a.join("/")) # use right "../.." sequence to get us back to the root of the buildpack
				stdout, status = Open3.capture2(
					{"STACK" => stack}, # env vars
					"php",
					"#{bp_root}/bin/util/platform.php",
					"#{bp_root}/support/installer",
					"https://lang-php.s3.us-east-1.amazonaws.com/dist-#{stack_with_arch}-stable/packages.json"
				)
				raise unless status.success?
				File.open("#{@install_tmpdir}/composer.json", "w") { |file| file.write(stdout) }
			end
			
			@export_tmpfile = Tempfile.new("export")
			@humanlog_tmpfile = Tempfile.new("humanlog")
			@profiled_tmpdir = Dir.mktmpdir("profile.d")
			@providedextensionslog_tmpfile = Tempfile.new("providedextensionslog")
			Dir.chdir(@install_tmpdir) do
				# regular install first
				cmd = <<~EOF
					exec {PHP_PLATFORM_INSTALLER_DISPLAY_OUTPUT_FDNO}> #{Shellwords.escape(@humanlog_tmpfile.path)}
					export PHP_PLATFORM_INSTALLER_DISPLAY_OUTPUT_FDNO
					export PHP_PLATFORM_INSTALLER_DISPLAY_OUTPUT_INDENT=4
					export export_file_path=#{Shellwords.escape(@export_tmpfile.path)}
					export profile_dir_path=#{Shellwords.escape(@profiled_tmpdir)}
					export providedextensionslog_file_path=#{Shellwords.escape(@providedextensionslog_tmpfile.path)}
					composer install --no-dev
				EOF
				@stdout, @stderr, @status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
				
				# the fixture has polyfill packages, where a userland package "provide"s a native extension
				# emulate a force-install for such a native extension, like bin/compile would
				@humanlog_native_tmpfile = Tempfile.new("humanlog_native")
				cmd = <<~EOF
					exec {PHP_PLATFORM_INSTALLER_DISPLAY_OUTPUT_FDNO}> #{Shellwords.escape(@humanlog_native_tmpfile.path)}
					export PHP_PLATFORM_INSTALLER_DISPLAY_OUTPUT_FDNO
					export PHP_PLATFORM_INSTALLER_DISPLAY_OUTPUT_INDENT=4
					export export_file_path=#{Shellwords.escape(@export_tmpfile.path)}
					export profile_dir_path=#{Shellwords.escape(@profiled_tmpdir)}
					composer require 'heroku-sys/ext-pq.native:*'
				EOF
				@stdout_native, @stderr_native, @status_native = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
			end
		end
		
		after(:all) do
			FileUtils.remove_entry(@install_tmpdir) if @install_tmpdir
			FileUtils.remove_entry(@profiled_tmpdir) if @profiled_tmpdir
			@export_tmpfile.unlink if @export_tmpfile
			@humanlog_tmpfile.unlink if @humanlog_tmpfile
			@humanlog_native_tmpfile.unlink if @humanlog_native_tmpfile
			@providedextensionslog_tmpfile.unlink if @providedextensionslog_tmpfile
		end
		
		it "performs an installation successfully" do
			expect(@status.exitstatus).to eq(0), "composer install failed, stderr: #{@stderr}, stdout: #{@stdout}"
			expect(@status_native.exitstatus).to eq(0), "composer require ext-pq.native failed, stderr: #{@stderr_native}, stdout: #{@stdout_native}"
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
			# remember from installer output if ext-gd was installed first or ext-newrelic
			order_to_check = @stderr.index("Enabling heroku-sys/ext-gd ") > @stderr.index("Installing heroku-sys/ext-newrelic ")
			# now expect the same order in `conf.d/` for the two extensions' configs
			expect(extensionconfigs.index {|f| f.include?("ext-gd.ini")} > extensionconfigs.index {|f| f.include?("ext-newrelic.ini")}).to eq(order_to_check)
			# also check ext-raphf came before ext-pq
			expect(@stderr_native.index("Installing heroku-sys/ext-raphf ")).to be < @stderr_native.index("Installing heroku-sys/ext-pq ")
			expect(extensionconfigs.index {|f| f.include?("ext-raphf.ini")}).to be < extensionconfigs.index {|f| f.include?("ext-pq.ini")}
		end
		
		it "enables shared extensions bundled with PHP if necessary" do
			expect(@stderr).to match("Enabling heroku-sys/ext-gd")
			expect(Dir.entries("#{@install_tmpdir}/etc/php/conf.d").any? {|f| f.include?("ext-gd.ini")}).to eq(true)
		end
		
		it "writes a log of userland polyfills that provide native extensions for subsequent install attempts" do
			expect(@providedextensionslog_tmpfile.read)
				.to include("symfony/polyfill-uuid heroku-sys/ext-uuid:*")
				.and include("dummypak/ext-pq-polyfill heroku-sys/ext-pq:*")
				.and include("dummypak/ext-imap-polyfill heroku-sys/ext-imap:8.3.0")
				.and include("symfony/polyfill-ctype heroku-sys/ext-ctype:*")
		end
		
		it "writes a human-readable log (with the expected indentation) to a given file descriptor" do
			version_triple = /\(\d+\.\d+\.\d+(\.\d+)?(\+[^)]+)?\)/ # 1.2.3 or 1.2.3+build2, optionally a fourth version dot
			bundled = /\(bundled with php\)/
			# the download progress indicator is written using ANSI cursors:
			# "    Downloaded 0/8 [>---------------------------]   0%\e[1G\e[2K    Downloaded 1/8 [===>------------------------]  12%\e[1G\e[2K    Downloaded 2/8 [=======>--------------------]  25%\e[1G\e[2K    Downloaded 4/8 [==============>-------------]  50%\e[1G\e[2K    Downloaded 5/8 [=================>----------]  62%\e[1G\e[2K    Downloaded 6/8 [=====================>------]  75%\e[1G\e[2K    Downloaded 7/8 [========================>---]  87%\e[1G\e[2K    Downloaded 8/8 [============================] 100%\e[1G\e[2K    - php (8.4.6)\n    - ext-sqlite3 (bundled with php)\n..."
			# we want to check that the download progress is actually printed, and then removed using ANSI codes
			# so we just match on the last progress report (since we're not always guaranteed to get one for every step depending on speed)
			expect(@humanlog_tmpfile.read).to match Regexp.new(<<~EOF)
				    Downloaded 5/5 \\[============================\\] 100%\
				\\e\\[1G\\e\\[2K\
				    - php #{version_triple.source}
				    - ext-newrelic #{version_triple.source}
				    - ext-gd #{bundled.source}
				    - apache #{version_triple.source}
				    - composer #{version_triple.source}
				    - nginx #{version_triple.source}
			EOF

			expect(@humanlog_native_tmpfile.read).to match Regexp.new(<<~EOF)
				    Downloaded 2/2 \\[============================\\] 100%\
				\\e\\[1G\\e\\[2K\
				    - ext-raphf #{version_triple.source}
				    - ext-pq #{version_triple.source}
			EOF

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
		
		describe "combined with a custom repository installs packages from that repo according to the priority given" do
			Dir.glob("composer-*.json", base: priorities_fixtures_subdir) do |testcase|
				it "in case #{testcase}" do
					Dir.chdir(priorities_fixtures_subdir) do |cwd|
						cmd = "COMPOSER=#{testcase} composer install --dry-run"
						stdout, stderr, status = Open3.capture3("bash -c #{Shellwords.escape(cmd)}")
						expect(status.exitstatus).to eq(0), "dry run install failed, stderr: #{stderr}, stdout: #{stdout}"
						
						if ["composer-duplicate.json"].include? testcase
							expect(stderr).to include("heroku-sys/php (8.0.8+otherbuild)")
						else
							expect(stderr).to include("heroku-sys/php (8.0.8)")
						end
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
					
					expect(generated_json).to eq(expected_json)
				end
			end
		end
	end
	
	describe "Repository Sync Operations Program" do
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
			it "fails the build and outputs cleaned up info from Composer" do
				new_app_with_stack_and_platrepo('test/fixtures/platform/generator/mycomposer.json',
					config: { "COMPOSER" => "mycomposer.json" },
					# add ext-foo to lock file, ext-bar only to mycomposer.json (so we get a warning about outdated lock file to assert against)
					before_deploy: -> { system("touch index.php; export COMPOSER=mycomposer.json; composer require --quiet --ignore-platform-reqs --no-install 'ext-foo:*' && composer require --quiet --ignore-platform-reqs --no-update 'ext-bar:*'") or raise "Failed to require dummy extensions" },
					run_multi: true,
					allow_failure: true
				).deploy do |app|
					expect(app.output).to include("Failed to install system packages!")
					# we want only "clean" package names for all the platform packages, without our "internal" prefix
					expect(app.output).not_to include("heroku-sys/")
					expect(app.output).not_to include("No composer.lock file present")
					expect(app.output).not_to include("Loading composer repositories with package information")
					expect(app.output).to include("Loading repositories with available runtimes and extensions")
					# check that Composer's output gets "quoted" using "> "
					expect(app.output).to include("> Updating dependencies")
					expect(app.output).not_to include("Potential causes:")
					# our internal intermediate package, we hide messages about that to avoid confusion
					expect(app.output).not_to include("satisfiable by mycomposer.json/mycomposer.lock")
					expect(app.output).to include("mycomposer.json/mycomposer.lock requires ext-foo * -> could not be found in any version, there may be a typo in the package name")
					# if composer.lock is out of date, there should be a reminder
					expect(app.output).to include("A possible cause for this error is your 'mycomposer.lock' file,")
					expect(app.output).to include("which is currently out of date, as changes have been made to")
					expect(app.output).to include("your 'mycomposer.json' that are not yet reflected in the lock file")
				end
			end
		end
		
		context "of a project that uses polyfills providing both bundled-with-PHP and third-party extensions" do
			# we set an invalid COMPOSER_AUTH on all of these to stop and fail the build on userland dependency install
			# we only need to check what happened during the platform install step, so that speeds things up
			it "treats polyfills for bundled-with-PHP and third-party extensions the same" do
				new_app_with_stack_and_platrepo('test/fixtures/platform/installer/polyfills', config: { "COMPOSER_AUTH" => "broken" }, allow_failure: true).deploy do |app|
					expect(app.output).to include("detected userland polyfill packages for PHP extensions")
					expect(app.output).not_to include("- ext-mbstring") # ext not required by any dependency, so should not be installed or even attempted ("- ext-mbstring...")
					out_before_polyfills, out_after_polyfills = app.output.split("detected userland polyfill packages for PHP extensions", 2)
					expect(out_before_polyfills).to include("- php (8.3")
					expect(out_after_polyfills).to include("- ext-ctype (already enabled)")
					expect(out_after_polyfills).to include("- ext-raphf (") # ext-pq, which we required, depends on it
					expect(out_after_polyfills).to include("- ext-pq (")
					expect(out_after_polyfills).to include("- ext-uuid (")
					expect(out_after_polyfills).to include("- ext-imap (bundled with php)")
				end
			end
			it "solves using the polyfills first and does not downgrade installed packages in the later native install step" do
				new_app_with_stack_and_platrepo('test/fixtures/platform/installer/polyfills-nodowngrade', config: { "COMPOSER_AUTH" => "broken" }, allow_failure: true).deploy do |app|
					expect(app.output).to include("detected userland polyfill packages for PHP extensions")
					expect(app.output).not_to include("- ext-mbstring") # ext not required by any dependency, so should not be installed or even attempted ("- ext-mbstring...")
					out_before_polyfills, out_after_polyfills = app.output.split("detected userland polyfill packages for PHP extensions", 2)
					expect(out_before_polyfills).to include("- php (8.4.")
					expect(out_after_polyfills).to include("- ext-ctype (already enabled)")
					expect(out_after_polyfills).to include("- ext-raphf (") # ext-pq, which we required, depends on it
					expect(out_after_polyfills).to include("- ext-pq (")
					expect(out_after_polyfills).to include("- ext-uuid (")
					expect(out_after_polyfills).not_to include("- ext-newrelic (")
					expect(out_after_polyfills).to include("no suitable native version of ext-newrelic available")
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
