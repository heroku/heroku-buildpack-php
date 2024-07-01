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
	"8.3"
end

def php_on_stack?(series)
	case ENV["STACK"]
		when "heroku-20"
			available = ["7.3", "7.4", "8.0", "8.1", "8.2", "8.3"]
		when "heroku-22"
			available = ["8.1", "8.2", "8.3"]
		else
			available = ["8.2", "8.3"]
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
