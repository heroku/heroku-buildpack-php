require_relative "php_shared_base"

describe "A basic PHP 7.2 application", :requires_php_on_stack => "7.2" do
	include_examples "A basic PHP application", "7.2"
end
