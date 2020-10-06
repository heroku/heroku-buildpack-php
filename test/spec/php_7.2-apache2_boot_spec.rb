require_relative "php_shared_boot"

describe "A PHP 7.2/Apache application for testing boot options", :requires_php_on_stack => "7.2" do
	include_examples "A PHP application for testing boot options", "7.2", "apache2"
end
