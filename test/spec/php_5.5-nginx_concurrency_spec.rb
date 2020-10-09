require_relative "php_shared_concurrency"

describe "A PHP 5.5/Nginx application for testing WEB_CONCURRENCY behavior", :requires_php_on_stack => "5.5" do
	include_examples "A PHP application for testing WEB_CONCURRENCY behavior", "5.5", "nginx"
end
