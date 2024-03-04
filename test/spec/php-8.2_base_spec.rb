require_relative "php_base_shared"

describe "A basic PHP 8.2 application", :requires_php_on_stack => "8.2" do
	include_examples "A basic PHP application", "8.2"
end
