require_relative "php_concurrency_shared"

describe "A PHP 8.2/Nginx application for testing WEB_CONCURRENCY behavior", :requires_php_on_stack => "8.2" do
	include_examples "A PHP application for testing WEB_CONCURRENCY behavior", "8.2", "nginx"
end
