require 'chef/mixin/shell_out'
require 'chef/dsl/recipe'
require 'chef/provisioning'
require 'chef/provisioning/aws_driver'

RSpec.configure do |rspec|
  rspec.run_all_when_everything_filtered = true
  rspec.filter_run :focus
  rspec.order = 'random'
  rspec.expect_with(:rspec) { |c| c.syntax = :expect }
  rspec.before { allow($stdout).to receive(:write) }
end
