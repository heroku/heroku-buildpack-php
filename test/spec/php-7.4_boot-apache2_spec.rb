require_relative "php_boot_shared"

describe "A PHP 7.4/Apache application for testing boot options", :requires_php_on_stack => "7.4" do
	include_examples "A PHP application for testing boot options", "7.4", "apache2"
end
