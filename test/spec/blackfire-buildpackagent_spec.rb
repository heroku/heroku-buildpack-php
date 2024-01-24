require_relative "blackfire_shared"

describe "A PHP application using ext-blackfire and, as its agent, buildpack" do
	include_examples "A PHP application using ext-blackfire and", "blackfireio/integration-heroku"
end
