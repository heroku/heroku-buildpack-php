require_relative "php_base_shared"

describe "A basic PHP 8.4 application", :requires_php_on_stack => "8.4" do
	include_examples "A basic PHP application", "8.4"
end
