require_relative "php_shared_boot"

describe "A PHP 5.6/Apache application for testing boot options", :requires_php_on_stack => "5.6" do
	include_examples "A PHP application for testing boot options", "5.6", "apache2"
end
