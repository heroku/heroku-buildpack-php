require_relative "php_base_shared"

describe "A basic PHP 8.3 application", :requires_php_on_stack => "8.3" do
	include_examples "A basic PHP application", "8.3"
end
