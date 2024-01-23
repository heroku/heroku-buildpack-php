require_relative "php_shared_boot"

describe "A PHP 8.1/Nginx application for testing boot options", :requires_php_on_stack => "8.1" do
	include_examples "A PHP application for testing boot options", "8.1", "nginx"
end
