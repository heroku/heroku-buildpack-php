require_relative "php_sigterm_shared"

describe "A PHP 7.4 application with long-running requests", :requires_php_on_stack => "7.4" do
	include_examples "A PHP application with long-running requests", "7.4", "nginx"
end
