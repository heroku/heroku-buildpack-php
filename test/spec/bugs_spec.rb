require_relative "spec_helper"

describe "A PHP application" do
	context "that has another buildpack running after the PHP buildpack" do
		it "puts binaries from composer's bin-dir on $PATH for subsequent buildpacks" do
			buildpacks = [
				:default,
				"https://github.com/weibeld/heroku-buildpack-run"
			]
			app = new_app_with_stack_and_platrepo("test/fixtures/bugs/export-composer-bin-dir", buildpacks: buildpacks)
			app.deploy do |app|
				expect(app.output).to match("atoum version")
			end
		end
	end
	
	context "that is built twice" do
		# sometimes, customers download a slug for an existing app and check that into a new repo
		# that means the source includes the binaries in .heroku/php/, which blows up the size by 100s of MB
		# it also causes the platform install to fail because Composer sees everything is there and no post-install hooks to set up $PATH etc will be run
		context "because of a slug getting used as the app source" do
			it "fails the build" do
				app = new_app_with_stack_and_platrepo("test/fixtures/default", allow_failure: true).tap do |app|
					app.before_deploy(:append) do
						FileUtils.mkdir_p(".heroku/php")
						FileUtils.touch(".heroku/php/composer.lock")
					end
				end
				app.deploy do |app|
					expect(app.output).to match("Your app source code contains artifacts from a previous build")
				end
			end
		end
		# it can also happen if the PHP buildpack runs twice during a build
		context "because the buildpack ran twice" do
			it "fails the build" do
				buildpacks = [
					:default,
					:default
				]
				app = new_app_with_stack_and_platrepo("test/fixtures/default", buildpacks: buildpacks, allow_failure: true)
				app.deploy do |app|
					expect(app.output).to match("Your app source code contains artifacts from a previous build")
				end
			end
		end
	end
	
	context "that during a build spawns a background process" do
		# app.deploy already re-tries for us three times, so we don't need rspec-retry to do the same
		it "does not hang at the end of the build due to file descriptors inherited by the background process", :retry => 1 do
			app = new_app_with_stack_and_platrepo("test/fixtures/bugs/child-process-fd-build-hang")
			app.deploy do |app|
				# This test case ensures that bin/compile does not leave open file descriptors around that children would inherit.
				# If those children are long-lived, like some background process that gets spawned during install (e.g. scoutapm-agent),
				# they would inherit such an FD, and unless they explicitly close it, the parent (bin/compile) will wait before terminating.
				# If the issue were to occur, the build would never finish, causing a test error.
				# Testing that app.deploy does not raise isn't possible, because it might genuinely hit a build timeout.
				# In a legitimate timeout case, we want to retry, but we cannot tell the two cases apart.
				# If the bug were to occur for all of app.deploy's retries, the next expect() will not execute, and the test will error.
				# For completeness' sake, verify that our test started the NR daemon via a composer 'compile' script
				_, out_after_compile = app.output.split("Running 'composer compile'", 2)
				expect(out_after_compile).to match(/listen="@newrelic-daemon"[^\n]+?startup=init/)
			end
		end
	end
	
	context "that uses the ScoutAPM integration for Laravel" do
		it "does not download and start the ScoutAPM agent during a build" do
			app = new_app_with_stack_and_platrepo(
				"test/fixtures/bugs/scoutapm",
				config: {
					# for the minimal Laravel to work correctly
					"LOG_CHANNEL": "stderr",
					"CACHE_STORE": "array",
					# to trigger ScoutAPM
					"SCOUT_KEY": "test",
					"SCOUT_MONITOR": true,
					"SCOUT_NAME": "test"
				}
			)
			app.deploy do |app|
				expect(app.output).to include("[Scout] Laravel Scout Agent is starting")
				expect(app.output).not_to match(/\[Scout\] Scout Core Agent .+ not connected yet, attempting to start/)
				expect(app.output).not_to include("[Scout] Downloading package")
				expect(app.output).not_to include("[Scout] Launching core agent")
				expect(app.output).to include("[Scout] Connection skipped, since monitoring is disabled")
				expect(app.output).to include("[Scout] Not sending payload, monitoring is not enabled")
			end
		end
	end
end
