require_relative "php_shared"

describe "A PHP 7.2 application with a composer.json", :requires_php_on_stack => "7.2" do
	include_examples "A PHP application with a composer.json", "7.2"
end
