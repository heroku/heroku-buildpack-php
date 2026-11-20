require_relative "spec_helper"

require "fileutils"
require "json"
require "open3"
require "shellwords"
require "tmpdir"

describe "The PIE extension build helper" do
	around do |example|
		Dir.mktmpdir("platform-pie-") do |root|
			@root = root
			@out_prefix = File.join(root, "php")
			@packages = File.join(root, "packages")
			@stub_bin = File.join(root, "commands")
			@build_dir = File.join(root, "build")
			FileUtils.mkdir_p([@packages, @stub_bin, @build_dir, File.join(@out_prefix, "bin"), File.join(@out_prefix, "include/php/main")])
			File.write(File.join(@out_prefix, "include/php/main/php.h"), "original PHP header\n")
			File.write(File.join(@out_prefix, "original-runtime"), "original PHP runtime\n")
			fixture = File.expand_path("../fixtures/platform/builder/pie/command.sh", __dir__)
			%w[curl sha256sum nproc strip python].each do |command|
				FileUtils.cp(fixture, File.join(@stub_bin, command))
				FileUtils.chmod(0755, File.join(@stub_bin, command))
			end
			%w[php php-config phpize].each do |command|
				FileUtils.cp(fixture, File.join(@out_prefix, "bin", command))
				FileUtils.chmod(0755, File.join(@out_prefix, "bin", command))
			end
			@environment = {
				"PATH" => "#{@stub_bin}:#{ENV.fetch("PATH")}",
				"WORKSPACE_DIR" => @packages,
				"PIE_TEST_ROOT" => root,
				"PIE_TEST_OUT_PREFIX" => @out_prefix,
				"PIE_TEST_PHP_VERSION" => "8.5.13",
				"PIE_TEST_PHP_API" => "20250925",
				"STACK" => "heroku-26",
				"S3_BUCKET" => "example-bucket",
				"S3_PREFIX" => "dist-heroku-26-amd64-develop/",
				"S3_REGION" => "eu-west-1",
				"NOW" => "2026-11-20 00:00:00",
				"MANIFEST_REQUIRE" => nil,
				"MANIFEST_CONFLICT" => nil,
				"MANIFEST_REPLACE" => nil,
				"MANIFEST_PROVIDE" => nil,
				"MANIFEST_EXTRA" => nil,
				"MANIFEST_CMD" => nil,
				"PIE_PACKAGE" => nil
			}
			example.run
		end
	end

	def run_recipe(version: "1.2.3", series: "8.5", settings: "PIE_PACKAGE=example/example\n")
		@package = "ext-example-#{version}_php-#{series}"
		recipe = File.join(@packages, @package)
		helper = File.expand_path("../../support/build/formulae/include/pie-ext", __dir__)
		File.write(recipe, "#!/usr/bin/env bash\ndep_name=ext-example\n#{settings}source #{Shellwords.escape(helper)}\n")
		@stdout, @stderr, @run_status = Open3.capture3(@environment, "bash", recipe, @out_prefix, chdir: @build_dir)
	end

	def recorded_arguments(command)
		File.binread(File.join(@root, "#{command}.args")).split("\0")
	end

	def expect_success
		expect(@run_status.exitstatus).to eq(0), "PIE helper failed: stdout: #{@stdout}, stderr: #{@stderr}"
	end

	def manifest
		JSON.parse(File.read(File.join(@build_dir, "#{@package}.composer.json")))
	end

	def expect_work_directory_removed
		curl_arguments = recorded_arguments("curl")
		phar_path = curl_arguments.fetch(curl_arguments.index("--output") + 1)
		expect(File.exist?(File.dirname(phar_path))).to be(false)
	end

	it "verifies the pinned PIE download before installing into a clean extension-only prefix" do
		run_recipe
		expect_success

		curl_arguments = recorded_arguments("curl")
		expect(curl_arguments).to include("--fail", "--silent", "--show-error", "--location", "https://github.com/php/pie/releases/download/1.5.5/pie.phar")
		expect(recorded_arguments("checksum")).to eq(["--check", "--strict", "-"])
		phar_path = curl_arguments.fetch(curl_arguments.index("--output") + 1)
		expect(File.read(File.join(@root, "checksum.input"))).to eq("2ca0dff6868f1b53c095625674deef38ac698588e0a25e4321cd834a5b7553bc  #{phar_path}\n")
		expect(File.readlines(File.join(@root, "events"), chomp: true)).to eq(%w[download verified install strip])

		extension_path = File.join(@out_prefix, "lib/php/extensions/no-debug-non-zts-20250925/example.so")
		expect(recorded_arguments("install")).to eq([
			phar_path, "install", "--no-interaction", "--skip-enable-extension", "--no-system-dependencies-check",
			"--with-php-config=#{@out_prefix}/bin/php-config", "--with-phpize-path=#{@out_prefix}/bin/phpize",
			"--make-parallel-jobs=3", "example/example:1.2.3"
		])
		expect(recorded_arguments("strip")).to eq(["--strip-unneeded", extension_path])
		expect(File.read(extension_path)).to eq("built extension\n")
		expect(Dir.glob("#{@out_prefix}/**/*", File::FNM_DOTMATCH).select { |path| File.file?(path) }).to eq([extension_path])

		install_root, pie_state = File.binread(File.join(@root, "install.env")).split("\0")
		expect(install_root).to eq(File.join(File.dirname(phar_path), "staging"))
		expect(pie_state).to eq(File.join(File.dirname(phar_path), "state"))
		expect(pie_state).not_to start_with("#{@out_prefix}/")
		expect_work_directory_removed
	end

	it "preserves package build metadata while selecting the exact extension version in PIE" do
		run_recipe(version: "1.2.3+pie.1")
		expect_success

		expect(recorded_arguments("install")).to include("example/example:1.2.3")
		expect(manifest).to include(
			"name" => "heroku-sys/ext-example",
			"version" => "1.2.3+pie.1",
			"type" => "heroku-sys-php-extension",
			"time" => "2026-11-20 00:00:00"
		)
		expect(manifest.fetch("dist")).to eq(
			"type" => "heroku-sys-tar",
			"url" => "https://example-bucket.s3.dualstack.eu-west-1.amazonaws.com/dist-heroku-26-amd64-develop/ext-example-1.2.3%2Bpie.1_php-8.5.tar.gz"
		)
		expect(manifest.fetch("require")).to eq(
			"heroku-sys/php" => "8.5.*",
			"heroku-sys/heroku" => "^26.0.0",
			"heroku/installer-plugin" => "^1.6.0"
		)
	end

	it "uses the build PHP series and stack rather than assuming one platform" do
		@environment.merge!("PIE_TEST_PHP_VERSION" => "8.4.16", "PIE_TEST_PHP_API" => "20240924", "STACK" => "heroku-24")
		run_recipe(series: "8.4")
		expect_success

		expect(manifest.fetch("require")).to include("heroku-sys/php" => "8.4.*", "heroku-sys/heroku" => "^24.0.0")
		expect(File.exist?(File.join(@out_prefix, "lib/php/extensions/no-debug-non-zts-20240924/example.so"))).to be(true)
	end

	it "preserves recipe manifest settings and PIE argument boundaries" do
		@environment.merge!(
			"MANIFEST_REQUIRE" => '{"heroku-sys/php":"8.5.*","heroku-sys/ext-raphf":"^2.0"}',
			"MANIFEST_CONFLICT" => '{"heroku-sys/ext-other":"*"}',
			"MANIFEST_REPLACE" => '{"heroku-sys/ext-legacy":"self.version"}',
			"MANIFEST_PROVIDE" => '{"heroku-sys/ext-feature":"1.0"}',
			"MANIFEST_EXTRA" => '{"zend":true}'
		)
		run_recipe(settings: "PIE_PACKAGE=vendor/example\nPIE_EXTRA=(--with-example='/opt/library path' --enable-feature)\n")
		expect_success

		expect(recorded_arguments("install").last(3)).to eq(["vendor/example:1.2.3", "--with-example=/opt/library path", "--enable-feature"])
		expect(manifest.fetch("require")).to include("heroku-sys/ext-raphf" => "^2.0")
		expect(manifest.fetch("conflict")).to eq("heroku-sys/ext-other" => "*")
		expect(manifest.fetch("replace")).to eq("heroku-sys/ext-legacy" => "self.version")
		expect(manifest.fetch("provide")).to eq("heroku-sys/ext-feature" => "1.0")
		expect(manifest.fetch("extra")).to eq("zend" => true)
	end

	it "rejects a bad PIE checksum without executing the download or replacing PHP" do
		real_sha256sum, lookup_status = Open3.capture2("bash", "-c", "command -v sha256sum")
		skip "sha256sum is required for the checksum failure case" unless lookup_status.success?
		@environment.merge!("PIE_TEST_CHECKSUM_FAILURE" => "1", "PIE_TEST_REAL_SHA256SUM" => real_sha256sum.strip)
		run_recipe

		expect(@run_status.exitstatus).not_to eq(0)
		expect(@stdout + @stderr).to include("FAILED")
		expect(File.exist?(File.join(@root, "install.args"))).to be(false)
		expect(File.read(File.join(@out_prefix, "original-runtime"))).to eq("original PHP runtime\n")
		expect(File.read(File.join(@out_prefix, "include/php/main/php.h"))).to eq("original PHP header\n")
		expect(File.exist?(File.join(@build_dir, "#{@package}.composer.json"))).to be(false)
		expect_work_directory_removed
	end

	it "cleans failed PIE installation state while preserving the original PHP runtime" do
		@environment["PIE_TEST_INSTALL_EXIT"] = "43"
		run_recipe

		expect(@run_status.exitstatus).to eq(43), "Unexpected helper output: #{@stdout}, #{@stderr}"
		expect(File.read(File.join(@out_prefix, "original-runtime"))).to eq("original PHP runtime\n")
		expect(File.read(File.join(@out_prefix, "include/php/main/php.h"))).to eq("original PHP header\n")
		expect(File.exist?(File.join(@root, "strip.args"))).to be(false)
		expect(File.exist?(File.join(@build_dir, "#{@package}.composer.json"))).to be(false)
		expect_work_directory_removed
	end

	it "requires an explicit PIE package before downloading or changing PHP" do
		run_recipe(settings: "")

		expect(@run_status.exitstatus).not_to eq(0)
		expect(@stderr).to include("Set PIE_PACKAGE to the vendor/package name")
		expect(File.exist?(File.join(@root, "curl.args"))).to be(false)
		expect(File.exist?(File.join(@root, "install.args"))).to be(false)
		expect(File.read(File.join(@out_prefix, "original-runtime"))).to eq("original PHP runtime\n")
	end
end
