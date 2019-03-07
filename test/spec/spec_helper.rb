require 'rspec/core'
require 'hatchet'
require 'fileutils'
require 'hatchet'
require 'rspec/retry'
require 'date'
require 'json'
require 'sem_version'
require 'shellwords'

ENV['RACK_ENV'] = 'test'

def product_hash(hash)
	hash.values[0].product(*hash.values[1..-1]).map{ |e| Hash[hash.keys.zip e] }
end

RSpec.configure do |config|
	config.filter_run focused: true unless ENV['IS_RUNNING_ON_TRAVIS']
	config.run_all_when_everything_filtered = true
	config.alias_example_to :fit, focused: true
	config.full_backtrace      = true
	config.verbose_retry       = true # show retry status in spec process
	config.default_retry_count = 2 if ENV['IS_RUNNING_ON_TRAVIS'] # retry all tests that fail again
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
