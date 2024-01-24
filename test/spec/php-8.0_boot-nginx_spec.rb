require_relative "php_boot_shared"

describe "A PHP 8.0/Nginx application for testing boot options", :requires_php_on_stack => "8.0" do
	include_examples "A PHP application for testing boot options", "8.0", "nginx"
end
