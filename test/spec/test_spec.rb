require_relative "spec_helper"

describe "A PHP application" do

  it "works with the getting started guide" do
    new_app_with_stack_and_platrepo("php-getting-started").tap do |app|
      app.deploy do
      # deploy works
      end
    end
  end

  it "checks for bad version" do
    new_app_with_stack_and_platrepo("php-getting-started", allow_failure: true).tap do |app|
      app.before_deploy do
        File.open("composer.json", "w+") do |f|
          f.write '{
          "require": {
            "php": "7.badversion"
          }}'
        end
      end
      app.deploy do
        expect(app.output).to include("Could not parse version constraint 7.badversion")
      end
    end
  end

  it "have absolute buildpack paths" do
    buildpacks = [
      :default,
      "https://github.com/sharpstone/force_absolute_paths_buildpack"
    ]
    new_app_with_stack_and_platrepo("php-getting-started", buildpacks: buildpacks).deploy do |app|
      #deploy works
    end
  end

  it "uses cache with ci" do
    app = new_app_with_stack_and_platrepo('test/fixtures/ci/devdeps')
    app.run_ci do |test_run|
      expect(test_run.output).to match("mockery/mockery")
      expect(test_run.output).to include("Downloading")
      test_run.run_again
      expect(test_run.output).to include("Loading from cache")
      expect(test_run.output).to_not include("Downloading")
    end
  end

  it "should restore cached dependencies when changing stack" do
    new_app_with_stack_and_platrepo("php-getting-started", stack: "heroku-18").deploy do |app, heroku|
      expect(app.output).to_not include("Loading from cache")

      app.update_stack("heroku-16")
      app.commit!
      app.push!

      expect(app.output).to include("Loading from cache")
    end
  end
end
