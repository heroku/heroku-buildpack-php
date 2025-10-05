ENV['HATCHET_BUILDPACK_BASE'] = 'https://github.com/heroku/heroku-buildpack-php.git'

require 'rspec/core'
require 'hatchet'
require 'fileutils'
require 'hatchet'
require 'rspec/retry'
require 'date'
require 'json'
require 'sem_version'
require 'shellwords'
require 'excon'

ENV['RACK_ENV'] = 'test'

def product_hash(hash)
	hash.values[0].product(*hash.values[1..-1]).map{ |e| Hash[hash.keys.zip e] }
end

RSpec.configure do |config|
	config.filter_run focused: true unless ENV['IS_RUNNING_ON_CI']
	config.run_all_when_everything_filtered = true
	config.alias_example_to :fit, focused: true
	config.filter_run_excluding :requires_php_on_stack => lambda { |series| !php_on_stack?(series) }
	config.filter_run_excluding :stack => lambda { |stack| !stack.include?(ENV['STACK']) }

	config.verbose_retry       = true # show retry status in spec process
	config.default_retry_count = 2 if ENV['IS_RUNNING_ON_CI'] # retry all tests that fail again...
	# config.exceptions_to_retry = [Excon::Errors::Timeout] #... if they're caused by these exception types
	config.fail_fast = 1 if ENV['IS_RUNNING_ON_CI']

	config.expect_with :rspec do |c|
		c.syntax = :expect
	end
end

def successful_request(app, options = {})
	retry_limit = options[:retry_limit] || 5
	retry_interval = options[:retry_interval] || 2
	path = options[:path] ? "/#{options[:path]}" : ''
	web_url = app.platform_api.app.info(app.name).fetch("web_url")
	Excon.get("#{web_url}#{path}", :idempotent => true, :expects => 200, :retry_limit => retry_limit, :retry_interval => retry_interval)
end

def successful_body(app, options = {})
	successful_request(app, options).body
end

def expect_exit(expect: :to, operator: :eq, code: 0)
	raise ArgumentError, "Expected a block but none given" unless block_given?
	run_obj = yield
	expect(run_obj.status.exitstatus).method(expect).call(
		method(operator).call(code),
		"Expected exit code #{run_obj.status.exitstatus} #{expect} be #{operator} to #{code}; output:\n#{run_obj.output}"
	)
	run_obj # so that can be tested too
end

def expected_default_php(stack)
	"8.4"
end

def php_on_stack?(series)
	case ENV["STACK"]
		when "heroku-22"
			available = ["8.1", "8.2", "8.3", "8.4"]
		else
			available = ["8.2", "8.3", "8.4"]
	end
	available.include?(series)
end

def new_app_with_stack_and_platrepo(*args, **kwargs)
	kwargs[:stack] ||= ENV["STACK"]
	kwargs[:config] ||= {}
	kwargs[:config]["HEROKU_PHP_PLATFORM_REPOSITORIES"] ||= ENV["HEROKU_PHP_PLATFORM_REPOSITORIES"]
	kwargs[:config].compact!
	app = Hatchet::Runner.new(*args, **kwargs)
	app.before_deploy(:append) do
		run!("cp #{__dir__}/../utils/waitforit.sh .")
	end
	app
end

def new_app_with_stack_and_platrepo_and_bin_report_dumper(*args, **kwargs)
	kwargs[:buildpacks] ||= [:default]
	kwargs[:buildpacks].prepend("heroku-community/inline")
	app = new_app_with_stack_and_platrepo(*args, **kwargs)
	app.before_deploy(:append) do
		FileUtils.mkdir("bin")
		File.open("bin/detect", "w", 0755) do |f|
			f.write <<~EOF
				#!/usr/bin/env bash
				echo "Inline bin/report dumper for PHP Hatchet tests"
			EOF
		end
		File.open("bin/compile", "w", 0755) do |f|
			f.write <<~EOF
				#!/usr/bin/env bash
				# find inline buildpack location (for writing export file) from process table
				# (we got exec'd by the inline buildpack, so we have to look it up in the buildpacks dir)
				read -a parent_args < <(ps -p "$PPID" -o args --no-headers)
				bp_dir="${parent_args[5]}/$(
					for arg in "${parent_args[@]:6}"; do
						if grep '^--buildpack=' <<<"$arg" | grep -q "heroku-community/inline"; then
							# compute SHA1 from the URL that was used, that's the subdir name
							echo -n "${arg/#--buildpack=/}" | sha1sum | cut -d" " -f1
						fi
					done
				)"
				# define EXIT trap that dumps the data ($2/$3 are expanded now)
				cat > "${bp_dir}/export" <<-EOX
					trap "
						echo -n '__BIN_REPORT_DUMP_MARKER_START__'
						jq -cjM < '$2/build-data/php.json'
						echo -n '__BIN_REPORT_DUMP_MARKER_END__'
						test -s '$3/FAIL_THIS_BUILD' && exit 1 # if config var set, abort
					" EXIT
				EOX
			EOF
		end
	end
	app.extend(AdditionalAppMethods::AppWithBinReportDumper)
	app
end

def run!(cmd)
	out = `#{cmd}`
	raise "Command #{cmd} failed: #{out}" unless $?.success?
	out
end

def retry_until(options = {})
	options = {
		retry: 1,
		sleep: 1,
		rescue: RSpec::Expectations::ExpectationNotMetError
	}.merge(options)

	options[:rescue] = Array(options[:rescue])

	tries = 0
	begin
		tries += 1
		yield
	rescue *options[:rescue] => e
		can_retry = tries < options[:retry]
		raise e unless can_retry

		sleep options[:sleep]
		retry
	end
end

module AdditionalAppMethods
	module AppWithBinReportDumper
		def bin_report_dump
			splits = output.split(/__BIN_REPORT_DUMP_MARKER_(START|END)__/)
			raise IndexError, "Could not find bin/report dump in output", caller if splits.length < 5
			JSON.parse(splits[-3]) # use the last dump - there might be multiple, since a trap prints them
		end
	end
end
