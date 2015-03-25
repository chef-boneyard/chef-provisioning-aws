# Bring in the RSpec monkeypatch before we do *anything*, so that builtin matchers
# will get the module.  Not strictly necessary, but cleaner that way.
require 'aws_support/deep_matcher/rspec_monkeypatches'

require 'chef/mixin/shell_out'
require 'chef/dsl/recipe'
require 'chef/provisioning'
require 'chef/provisioning/aws_driver'
require 'chef/platform'
require 'chef/run_context'
require 'chef/event_dispatch/dispatcher'
require 'aws_support'

RSpec.configure do |rspec|
  rspec.run_all_when_everything_filtered = true
  rspec.filter_run :focus
#  rspec.order = 'random'
  rspec.expect_with(:rspec) { |c| c.syntax = :expect }
#  rspec.before { allow($stdout).to receive(:write) }
end

#Chef::Log.level = :debug

require 'cheffish/rspec/matchers'
