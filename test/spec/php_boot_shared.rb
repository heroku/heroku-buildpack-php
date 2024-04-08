require_relative "spec_helper"
require "securerandom"

shared_examples "A PHP application for testing boot options" do |series, server|
	# the matrix of options and arguments to test
	# we will generate relevant combinations of these using a helper
	# numeric keys mean the values are passed as an argument and not as key/value options
	# nil means the argument/option will be omitted
	# true means the option will be passed without a value
	# false means the option will be passed without a value, and the invocation will be expected to fail
	# any string value that contains "broken" will be expected to fail
	matrices = {
		"apache2" => {
			0 => [
				"heroku-php-apache2"
			],
			'--verbose' => [
				true
			],
			'-C' => [
				nil,
				"conf/apache2.server.include.conf",
				"conf/apache2.server.include.dynamic.conf.php",
				"conf/apache2.server.include.broken"
			],
			'-F' => [
				nil,
				"conf/fpm.include.conf",
				"conf/fpm.include.dynamic.conf.php",
				"conf/fpm.include.broken"
			],
			1 => [ # document root argument
				nil,
				"docroot/",
				"brokendocroot/"
			]
		},
		"nginx" => {
			0 => [
				"heroku-php-nginx"
			],
			'--verbose' => [
				true
			],
			'-C' => [
				nil,
				"conf/nginx.server.include.conf",
				"conf/nginx.server.include.dynamic.conf.php",
				"conf/nginx.server.include.broken"
			],
			'-F' => [
				nil,
				"conf/fpm.include.conf",
				"conf/fpm.include.dynamic.conf.php",
				"conf/fpm.include.broken"
			],
			1 => [ # document root argument
				nil,
				"docroot/",
				"brokendocroot/"
			]
		}
	}
	# generate combinations for given keys, or all if nil
	def self.genmatrix(matrix, keys = nil)
		product_hash(matrix.select {|k,v| !keys || keys.include?(k) })
	end
	# generate command based on given combination info hash
	def self.gencmd(args)
		args.compact.map { |k,v|
			if k.is_a? Numeric
				ret = v.shellescape # it's an argument, so we want the value only
			else
				ret = k.shellescape
				unless !!v == v # check if boolean
					ret.concat(" #{v.shellescape}") # --foobar flags have no values
				end
			end
			ret
		}.join(" ").strip
	end
	
	matrix = matrices[server]
	context "running PHP #{series} and the #{server} web server" do
		before(:all) do
			@app = new_app_with_stack_and_platrepo('test/fixtures/bootopts',
				before_deploy: -> { system("composer require --quiet --ignore-platform-reqs php '#{series}.*'") or raise "Failed to require PHP version" },
				run_multi: true
			)
			@app.deploy
		end
		
		after(:all) do
			@app.teardown!
		end
		
		# we don't want to test all possible combinations of all arguments, as that'd be thousands
		interesting = Array.new
		interesting << [0, '--verbose', 1] # with and without document root
		interesting << [0, '--verbose', '-C']
		interesting << [0, '--verbose', '-F']
		combinations = interesting.map {|v| genmatrix(matrix, v)}.flatten(1).uniq
		# # a few more "manual" cases
		combinations << {0 => "heroku-php-#{server}", "--verbose" => true, "-C" => "conf/#{server}.server.include.conf", "-F" => "conf/fpm.include.conf"}
		
		commands = Array.new
		combinations.each do |combination|
			cmd = gencmd(combination)
			if combination.value?(false) or cmd.match("broken")
				commands << {group: "does not boot", title: "using command #{cmd}", cmd: "timeout 10 #{cmd}", expect: :not_to, operator: :eq, code: 124}
			else
				commands << {group: "boots", title: "using command #{cmd}", cmd: "./waitforit.sh 10 'ready for connections' #{cmd}", expect: :to, operator: :eq, code: 0}
			end
		end
		
		# some more simple arg cases
		commands << {group: "does not boot", title: "using too many arguments", cmd: "timeout 10 heroku-php-#{server} docroot/ anotherarg", expect: :to, operator: :eq, code: 2}
		commands << {group: "does not boot", title: "using unknown options", cmd: "timeout 10 heroku-php-#{server} --what -u erp", expect: :to, operator: :eq, code: 2}
		
		commands.group_by { |command| command[:group] }.each do |group, examples|
			
			context group do
				before(:all) do
					delimiter = SecureRandom.uuid
					# run the command, then print a newline and the exit status (which we also test against)
					# there are very rare cases of stderr and stdout getting read (by the dyno runner) slightly out of order
					# if that happens, the last stderr line(s) from the program might get picked up after the next thing we echo
					# for that reason, we redirect stderr to stdout
					run_cmds = examples
						.map { |example| "#{example[:cmd]} 2>&1; echo $'\\n'$?" }
						.join("; echo -n '#{delimiter}'; ")
					retry_until retry: 3, sleep: 5 do
						@run = @app.run(run_cmds).split(delimiter)
					end
				end
				
				examples.each_with_index do |example, index|
					it example[:title] do
						output, _, code = @run[index].rstrip.rpartition("\n")
						# in case this one has failed, print what the previous runs have done - maybe something unexpected (but still with correct exit code) happened that can aid debugging
						previous = @run.slice(0, index).map.with_index { |run, idx| out, _, status = run.rstrip.rpartition("\n"); "Output for '#{examples[idx][:cmd]}' (exited #{status}):\n#{out}" }
						if previous.empty?
							previous = ""
						else
							previous = "\n\nFor reference, here is the output from the previous commands in this run:\n\n#{previous.join("\n\n")}"
						end
						expect(code).method(example[:expect]).call(
							method(example[:operator]).call(example[:code].to_s),
							"Expected exit code #{code} #{example[:expect]} be #{example[:operator]} to #{example[:code]}; output for '#{example[:cmd]}':\n#{output}#{previous}"
						)
					end
				end
			end
		end
	end
end
