require_relative "php_boot_shared"

describe "A PHP 8.1/Apache application for testing boot options", :requires_php_on_stack => "8.1" do
	include_examples "A PHP application for testing boot options", "8.1", "apache2"
end
