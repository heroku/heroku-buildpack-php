require_relative "php_shared"

describe "A PHP 7.1 application with a composer.json", :requires_php_on_stack => "7.1" do
	include_examples "A PHP application with a composer.json", "7.1"
end
