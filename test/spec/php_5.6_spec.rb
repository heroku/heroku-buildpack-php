require_relative "php_shared"

describe "A PHP 5.6 application with a composer.json", :requires_php_on_stack => "5.6" do
	include_examples "A PHP application with a composer.json", "5.6"
end
