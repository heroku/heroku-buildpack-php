require_relative "php_shared_boot"

describe "A PHP 5.5/Nginx application for testing boot options", :requires_php_on_stack => "5.5" do
	include_examples "A PHP application for testing boot options", "5.5", "nginx"
end
