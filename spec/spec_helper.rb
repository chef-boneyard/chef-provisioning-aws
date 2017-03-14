begin
  require 'simplecov'
  SimpleCov.start
rescue LoadError; end

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
require 'rspec'

RSpec.configure do |rspec|
  rspec.run_all_when_everything_filtered = true
  rspec.filter_run :focus
  rspec.filter_run_excluding :super_slow => true
#  rspec.order = 'random'
  rspec.expect_with(:rspec) { |c| c.syntax = :expect }
#  rspec.before { allow($stdout).to receive(:write) }
  rspec.example_status_persistence_file_path = "spec/persistence_file.txt"
end

#Chef::Log.level = :debug
Chef::Config[:log_level] = :warn

require 'cheffish/rspec/matchers'
