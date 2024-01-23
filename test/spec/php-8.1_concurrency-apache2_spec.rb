require_relative "php_concurrency_shared"

describe "A PHP 8.1/Apache application for testing WEB_CONCURRENCY behavior", :requires_php_on_stack => "8.1" do
	include_examples "A PHP application for testing WEB_CONCURRENCY behavior", "8.1", "apache2"
end
