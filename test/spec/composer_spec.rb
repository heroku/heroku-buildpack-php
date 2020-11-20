require_relative "spec_helper"

describe "A PHP application" do
	context "with a composer.lock generatead by an old version of Composer" do
		it "builds using Composer 1.x" do
			new_app_with_stack_and_platrepo('test/fixtures/composer/basic_lock_oldv1').deploy do |app|
				expect(app.output).to match(/- composer \(1/)
				expect(app.output).to match(/Composer version 1/)
			end
		end
	end
	context "with a composer.lock generatead by a late version 1 of Composer" do
		it "builds using Composer 1.x" do
			new_app_with_stack_and_platrepo('test/fixtures/composer/basic_lock_v1').deploy do |app|
				expect(app.output).to match(/- composer \(1/)
				expect(app.output).to match(/Composer version 1/)
			end
		end
	end
	context "with a composer.lock generatead by version 2 of Composer" do
		it "builds using Composer 2.x" do
			new_app_with_stack_and_platrepo('test/fixtures/composer/basic_lock_v2').deploy do |app|
				expect(app.output).to match(/- composer \(2/)
				expect(app.output).to match(/Composer version 2/)
			end
		end
	end
end
