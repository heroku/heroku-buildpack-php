require_relative "php_shared_boot"

describe "A PHP 5.6/Nginx application for testing boot options", :requires_php_on_stack => "5.6" do
	include_examples "A PHP application for testing boot options", "5.6", "nginx"
end
