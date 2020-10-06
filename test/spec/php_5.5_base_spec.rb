require_relative "php_shared_base"

describe "A basic PHP 5.5 application", :requires_php_on_stack => "5.5" do
	include_examples "A basic PHP application", "5.5"
end
