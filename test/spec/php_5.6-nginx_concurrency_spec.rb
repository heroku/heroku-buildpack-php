require_relative "php_shared_concurrency"

describe "A PHP 5.6/Nginx application for testing WEB_CONCURRENCY behavior", :requires_php_on_stack => "5.6" do
	include_examples "A PHP application for testing WEB_CONCURRENCY behavior", "5.6", "nginx"
end
