require_relative "php_shared"

describe "A PHP 7.3 application with a composer.json", :requires_php_on_stack => "7.3" do
	include_examples "A PHP application with a composer.json", "7.3"
end
