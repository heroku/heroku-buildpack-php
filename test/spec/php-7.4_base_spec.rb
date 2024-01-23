require_relative "php_base_shared"

describe "A basic PHP 7.4 application", :requires_php_on_stack => "7.4" do
	include_examples "A basic PHP application", "7.4"
end
