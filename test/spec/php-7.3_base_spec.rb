require_relative "php_base_shared"

describe "A basic PHP 7.3 application", :requires_php_on_stack => "7.3" do
	include_examples "A basic PHP application", "7.3"
end
