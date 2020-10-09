require_relative "php_shared_base"

describe "A basic PHP 7.0 application", :requires_php_on_stack => "7.0" do
	include_examples "A basic PHP application", "7.0"
end
