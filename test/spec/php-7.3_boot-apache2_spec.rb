require_relative "php_shared_boot"

describe "A PHP 7.3/Apache application for testing boot options", :requires_php_on_stack => "7.3" do
	include_examples "A PHP application for testing boot options", "7.3", "apache2"
end
