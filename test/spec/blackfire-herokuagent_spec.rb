require_relative "blackfire_shared"

describe "A PHP application using ext-blackfire and, as its agent," do
	include_examples "A PHP application using ext-blackfire and", "our blackfire package"
end
