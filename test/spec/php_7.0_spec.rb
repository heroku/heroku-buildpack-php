require_relative "php_shared"

describe "A PHP 7.0 application with a composer.json", :requires_php_on_stack => "7.0" do
	include_examples "A PHP application with a composer.json", "7.0"
end
