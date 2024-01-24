require_relative "php_sigterm_shared"

describe "A PHP 8.3 application with long-running requests", :requires_php_on_stack => "8.3" do
	include_examples "A PHP application with long-running requests", "8.3", "apache2"
end
