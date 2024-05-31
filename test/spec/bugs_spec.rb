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
end
