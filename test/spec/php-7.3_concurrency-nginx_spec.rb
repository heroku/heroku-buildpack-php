require_relative "php_shared_concurrency"

describe "A PHP 7.3/Nginx application for testing WEB_CONCURRENCY behavior", :requires_php_on_stack => "7.3" do
	include_examples "A PHP application for testing WEB_CONCURRENCY behavior", "7.3", "nginx"
end
