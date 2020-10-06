require_relative "php_shared_boot"

describe "A PHP 7.4/Nginx application for testing boot options", :requires_php_on_stack => "7.4" do
	include_examples "A PHP application for testing boot options", "7.4", "nginx"
end
