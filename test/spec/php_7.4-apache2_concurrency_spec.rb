require_relative "php_shared_concurrency"

describe "A PHP 7.4/Apache application for testing WEB_CONCURRENCY behavior", :requires_php_on_stack => "7.4" do
	include_examples "A PHP application for testing WEB_CONCURRENCY behavior", "7.4", "apache2"
end
