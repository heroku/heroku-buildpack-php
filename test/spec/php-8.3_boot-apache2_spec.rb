require_relative "php_boot_shared"

describe "A PHP 8.3/Apache application for testing boot options", :requires_php_on_stack => "8.3" do
	include_examples "A PHP application for testing boot options", "8.3", "apache2"
end
