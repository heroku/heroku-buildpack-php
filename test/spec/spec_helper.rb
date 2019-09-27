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

module Hatchet
	class App
		attr_reader :name, :stack, :directory, :repo_name, :app_config
	end
	
	class TestRun
		# override the default handling to also include stack and env vars in app.json
		def source_blob_url
			@app.in_directory do
				app_json = JSON.parse(File.read("app.json")) if File.exist?("app.json")
				app_json ||= {}
				app_json["environments"]                       ||= {}
				app_json["environments"]["test"]               ||= {}
				app_json["environments"]["test"]["buildpacks"] = @buildpacks.map {|b| { url: b } }
				app_json["environments"]["test"]["env"]        ||= {}
				
				# begin override: set stack into app.json
				app_json["stack"]                              ||= @app.stack if @app.stack && !@app.stack.empty?
				# end override
				
				# begin override: copy in env too, so we get e.g. the correct HEROKU_PHP_PLATFORM_REPOSITORIES
				app_json["environments"]["test"]["env"]        = @app.app_config.merge(app_json["environments"]["test"]["env"]) # so we get HEROKU_PHP_PLATFORM_REPOSITORIES in there
				# end override
				
				File.open("app.json", "w") {|f| f.write(JSON.generate(app_json)) }
				
				`tar c . | gzip -9 > slug.tgz`
				
				source_put_url = @app.create_source
				Hatchet::RETRIES.times.retry do
					@api_rate_limit.call
					Excon.put(source_put_url,
						expects: [200],
						body:    File.read('slug.tgz'))
				end
			end
			return @app.source_get_url
		end
	end
end

def product_hash(hash)
	hash.values[0].product(*hash.values[1..-1]).map{ |e| Hash[hash.keys.zip e] }
end

RSpec.configure do |config|
	config.filter_run focused: true unless ENV['IS_RUNNING_ON_TRAVIS']
	config.run_all_when_everything_filtered = true
	config.alias_example_to :fit, focused: true
	config.filter_run_excluding :requires_php_on_stack => lambda { |series| !php_on_stack?(series) }
	config.filter_run_excluding :stack => lambda { |stack| ENV['STACK'] != stack }
	
	config.verbose_retry       = true # show retry status in spec process
	config.default_retry_count = 2 if ENV['IS_RUNNING_ON_TRAVIS'] # retry all tests that fail again...
	config.exceptions_to_retry = [Excon::Errors::Timeout] #... if they're caused by these exception types
	config.fail_fast = 1 if ENV['IS_RUNNING_ON_TRAVIS']
	
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
			"7.3"
	end
end

def php_on_stack?(series)
	case ENV["STACK"]
		when "cedar-14"
			available = ["5.5", "5.6", "7.0", "7.1", "7.2", "7.3"]
		when "heroku-16"
			available = ["5.6", "7.0", "7.1", "7.2", "7.3"]
		else
			available = ["7.1", "7.2", "7.3"]
	end
	available.include?(series)
end

def new_app_with_stack_and_platrepo(*args, **kwargs)
	kwargs[:stack] ||= ENV["STACK"]
	kwargs[:config] ||= {}
	kwargs[:config]["HEROKU_PHP_PLATFORM_REPOSITORIES"] ||= ENV["HEROKU_PHP_PLATFORM_REPOSITORIES"]
	kwargs[:config].compact!
	Hatchet::Runner.new(*args, **kwargs)
end
