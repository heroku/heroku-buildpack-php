require_relative "php_concurrency_shared"

describe "A PHP 8.1/Nginx application for testing WEB_CONCURRENCY behavior", :requires_php_on_stack => "8.1" do
	include_examples "A PHP application for testing WEB_CONCURRENCY behavior", "8.1", "nginx"
end
