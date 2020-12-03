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
require 'open3'
require 'timeout'

ENV['RACK_ENV'] = 'test'

def product_hash(hash)
	hash.values[0].product(*hash.values[1..-1]).map{ |e| Hash[hash.keys.zip e] }
end

RSpec.configure do |config|
	config.filter_run focused: true unless ENV['IS_RUNNING_ON_CI']
	config.run_all_when_everything_filtered = true
	config.alias_example_to :fit, focused: true
	config.filter_run_excluding :requires_php_on_stack => lambda { |series| !php_on_stack?(series) }
	config.filter_run_excluding :stack => lambda { |stack| ENV['STACK'] != stack }

	config.verbose_retry       = true # show retry status in spec process
	config.default_retry_count = 2 if ENV['IS_RUNNING_ON_CI'] # retry all tests that fail again...
	# config.exceptions_to_retry = [Excon::Errors::Timeout] #... if they're caused by these exception types
  # config.fail_fast = 1 if ENV['IS_RUNNING_ON_CI']

	config.expect_with :rspec do |c|
		c.syntax = :expect
	end
end

def successful_body(app, options = {})
	retry_limit = options[:retry_limit] || 100
	path = options[:path] ? "/#{options[:path]}" : ''
	Excon.get("http://#{app.name}.herokuapp.com#{path}", :idempotent => true, :expects => 200, :retry_limit => retry_limit).body
end

def expect_exit(expect: :to, operator: :eq, code: 0)
	raise ArgumentError, "Expected a block but none given" unless block_given?
	output = yield
	expect($?.exitstatus).method(expect).call(
		method(operator).call(code),
		"Expected exit code #{$?.exitstatus} #{expect} be #{operator} to #{code}; output:\n#{output}"
	)
	output # so that can be tested too
end

def expected_default_php(stack)
	case stack
		when "cedar-14", "heroku-16"
			"5.6"
		else
			"7.4"
	end
end

def php_on_stack?(series)
	case ENV["STACK"]
		when "cedar-14"
			available = ["5.5", "5.6", "7.0", "7.1", "7.2", "7.3"]
		when "heroku-16"
			available = ["5.6", "7.0", "7.1", "7.2", "7.3", "7.4"]
		when "heroku-18"
			available = ["7.1", "7.2", "7.3", "7.4"]
		else
			available = ["7.3", "7.4", "8.0"]
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

module Hatchet
	class App
    def run(cmd_type, command = DefaultCommand, options = {}, &block)
      case command
      when Hash
        options.merge!(command)
        command = cmd_type.to_s
      when nil
        STDERR.puts "Calling App#run with an explicit nil value in the second argument is deprecated."
        STDERR.puts "You can pass in a hash directly as the second argument now.\n#{caller.join("\n")}"
        command = cmd_type.to_s
      when DefaultCommand
        command = cmd_type.to_s
      else
        command = command.to_s
      end

      allow_run_multi! if @run_multi

      run_obj = Hatchet::HerokuRun.new(
        command,
        app: self,
        retry_on_empty: options.fetch(:retry_on_empty, !ENV["HATCHET_DISABLE_EMPTY_RUN_RETRY"]),
        retry_delay: @run_multi ? 0 : (ENV["HATCHET_RUN_RETRY_DELAY"] || 5).to_i,
        heroku: options[:heroku],
        raw: options[:raw],
        timeout: options.fetch(:timeout, (ENV["HATCHET_DEFAULT_RUN_TIMEOUT"] || 60).to_i)
      ).call

      return options[:return_obj] ? run_obj : run_obj.output
    end
    def run_multi(command, options = {}, &block)
      raise "Block required" if block.nil?
      allow_run_multi!

      run_thread = Thread.new do
        run_obj = Hatchet::HerokuRun.new(
          command,
          app: self,
          retry_on_empty: options.fetch(:retry_on_empty, !ENV["HATCHET_DISABLE_EMPTY_RUN_RETRY"]),
          retry_delay: @run_multi ? 0 : (ENV["HATCHET_RUN_RETRY_DELAY"] || 5).to_i,
          heroku: options[:heroku],
          raw: options[:raw],
          timeout: options.fetch(:timeout, (ENV["HATCHET_DEFAULT_RUN_TIMEOUT"] || 60).to_i)
        ).call

        yield run_obj.output, run_obj.status
      end
      run_thread.abort_on_exception = true

      @run_multi_array << run_thread

      true
    end
	end
  class HerokuRun
    class HerokuRunEmptyOutputError < RuntimeError; end
    class HerokuRunTimeoutError < RuntimeError; end

    attr_reader :command

    def initialize(
      command,
      app: ,
      heroku: {},
      retry_on_empty: !ENV["HATCHET_DISABLE_EMPTY_RUN_RETRY"],
      retry_delay: 0,
      raw: false,
      stderr: $stderr,
      timeout: 0)

      @raw = raw
      @app = app
      @timeout = timeout
      @command = build_heroku_command(command, heroku || {})
      @retry_on_empty = retry_on_empty
      @retry_delay = retry_delay
      @stderr = stderr
      @output = ""
      @status = nil
      @empty_fail_count = 0
      @timeout_fail_count = 0
    end

    def output
      raise "You must run `call` on this object first" unless @status
      @output
    end

    def status
      raise "You must run `call` on this object first" unless @status
      @status
    end

    def call
      begin
        execute!
      rescue HerokuRunEmptyOutputError => e
        if @retry_on_empty and (@empty_fail_count += 1) <=3
          message = String.new("Empty output from run #{@dyno_id} with command #{@command}, retrying in #{@retry_delay} seconds.")
          message << "\nTo disable pass in `retry_on_empty: false` or set HATCHET_DISABLE_EMPTY_RUN_RETRY=1 globally"
          message << "\nfailed_count: #{@empty_fail_count}"
          message << "\nreleases: #{@app.releases}"
          message << "\n#{caller.join("\n")}"
          @stderr.puts message
          sleep(@retry_delay) # without run_multi, this will prevent frequent "can only run one free dyno" errors
          retry
        end
      rescue HerokuRunTimeoutError => e
        if (@timeout_fail_count += 1) <= 3
          message = String.new("Run #{@dyno_id} with command #{@command} timed out after #{@timeout}, stopping dyno and re-trying.")
          message << "\nOutput until moment of termination was: #{@output}"
          message << "\nTo disable pass in `timeout: 0` or set HATCHET_DEFAULT_RUN_TIMEOUT=0 globally"
          message << "\nfailed_count: #{@timeout_fail_count}"
          message << "\nreleases: #{@app.releases}"
          message << "\n#{caller.join("\n")}"
          @stderr.puts message
          @app.platform_api.dyno.stop(@app.name, @dyno_id) if @dyno_id
          sleep(@retry_delay == 0 ? 0 : 1) # a second should be enough for all cases after our explicit stop
          retry
        end
      end

      self
    end

    private def execute!
      ShellThrottle.new(platform_api: @app.platform_api).call do |throttle|
        run_shell!
        throw(:throttle) if output.match?(/reached the API rate limit/)
      end
    end

    def run_shell!
      @output = ""
      @dyno_id = nil
      Open3.popen3(@command) do |stdin, stdout, stderr, wait_thread|
      begin
        Timeout.timeout(@timeout) do
          Thread.new do
            until stdout.eof? do
              @output += stdout.gets
            end
          rescue IOError # eof? and gets race condition
          end
          Thread.new do
            until stderr.eof? do
              @stderr.puts line = stderr.gets
              if !@dyno_id and run = line.match(/, (run\.\d+)/)
                @dyno_id = run.captures.first
              end
            end
          rescue IOError # eof? and gets race condition
          end
          @status = wait_thread.value # wait for termination
        end
        rescue Timeout::Error
          Process.kill("TERM", wait_thread.pid)
          @status = wait_thread.value # wait for termination
        end
        # FIXME: usage of $? in tests is very likely not threadsafe, and does not allow a test to distinguish between a TERM by us or inside the dyno
        # this should be part of a proper interface to the run result instead but that's a breaking change
        # change app.run to return whole run object which has to_s and to_str for output?
        status = @status.signaled? ? @status.termsig+128 : @status.exitstatus # a signaled program will not have an exit status, but the shell represents that case as 128+$signal, so e.g. 128+15=143 for SIGTERM
        `exit #{status}` # re-set $? for tests that rely on us previously having used backticks
        raise HerokuRunTimeoutError if @status.signaled? # program got terminated by our SIGTERM, raise
        raise HerokuRunEmptyOutputError if @output.empty?
      end
    end

    private def build_heroku_command(command, options = {})
      command = command.shellescape unless @raw

      default_options = { "app" => @app.name, "exit-code" => nil }
      heroku_options_array = (default_options.merge(options)).map do |k,v|
        # This was a bad interface decision
        next if v == Hatchet::App::SkipDefaultOption # for forcefully removing e.g. --exit-code, a user can pass this

        arg = "--#{k.to_s.shellescape}"
        arg << "=#{v.to_s.shellescape}" unless v.nil? # nil means we include the option without an argument
        arg
      end

      "heroku run #{heroku_options_array.compact.join(' ')} -- #{command}"
    end
  end
end
