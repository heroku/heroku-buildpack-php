require_relative "php_boot_shared"

describe "A PHP 8.4/Nginx application for testing boot options", :requires_php_on_stack => "8.4" do
	include_examples "A PHP application for testing boot options", "8.4", "nginx"
end
