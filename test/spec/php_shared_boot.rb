require_relative "spec_helper"

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
		combinations.each do | combination |
			cmd = gencmd(combination)
			context "launching using `#{cmd}'" do
				if combination.value?(false) or cmd.match("broken")
					it "does not boot" do
						# check if "timeout" exited with a status other than 124, which means the process exited (due to the expected error) before "timeout" stepped in after the given duration (five seconds) and terminated it
						expect_exit(expect: :not_to, code: 124) { @app.run("timeout 15 #{cmd}", :return_obj => true) }
					end
				else
					it "boots" do
						# check if "waitforit" exited with status 0, which means the process successfully output the expected message
						expect_exit(expect: :to, code: 0) { @app.run("./waitforit.sh 15 'ready for connections' #{cmd}", :return_obj => true) }
					end
				end
			end
		end
		
		context "launching using too many arguments" do
			it "fails to boot" do
				expect_exit(expect: :to, code: 2) { @app.run("timeout 10 heroku-php-#{server} docroot/ anotherarg", :return_obj => true) }
			end
		end
		
		context "launching using unknown options" do
			it "fails to boot" do
				expect_exit(expect: :to, code: 2) { @app.run("timeout 10 heroku-php-#{server} --what -u erp", :return_obj => true) }
			end
		end
	end
end
