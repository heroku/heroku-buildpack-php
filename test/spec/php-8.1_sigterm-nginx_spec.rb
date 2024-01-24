require_relative "php_sigterm_shared"

describe "A PHP 8.1 application with long-running requests", :requires_php_on_stack => "8.1" do
	include_examples "A PHP application with long-running requests", "8.1", "nginx"
end
