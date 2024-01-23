require_relative "php_concurrency_shared"

describe "A PHP 8.0/Apache application for testing WEB_CONCURRENCY behavior", :requires_php_on_stack => "8.0" do
	include_examples "A PHP application for testing WEB_CONCURRENCY behavior", "8.0", "apache2"
end
