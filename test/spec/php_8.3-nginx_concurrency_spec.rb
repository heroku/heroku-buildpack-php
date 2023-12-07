require_relative "php_shared_concurrency"

describe "A PHP 8.3/Nginx application for testing WEB_CONCURRENCY behavior", :requires_php_on_stack => "8.3" do
	include_examples "A PHP application for testing WEB_CONCURRENCY behavior", "8.3", "nginx"
end
