require_relative "php_shared_boot"

describe "A PHP 7.4/Apache application for testing boot options", :requires_php_on_stack => "8.0" do
	include_examples "A PHP application for testing boot options", "8.0", "apache2"
end
