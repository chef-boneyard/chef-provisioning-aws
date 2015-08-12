require 'bundler'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

task :default => :spec

ENV['AWS_TEST_DRIVER'] ||= "aws"

desc "run all non-integration specs"
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  # TODO add back integration tests whenever we have strategy for keys
  spec.exclude_pattern = 'spec/integration/**/*_spec.rb'
end

desc "run integration specs"
RSpec::Core::RakeTask.new(:integration) do |spec|
  spec.pattern = 'spec/integration/**/*_spec.rb'
end

desc "run :super_slow specs (machine/machine_image)"
RSpec::Core::RakeTask.new(:slow) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rspec_opts = "-t super_slow"
end

desc "run all specs, except :super_slow"
RSpec::Core::RakeTask.new(:all) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
end

desc "run all specs, including :super_slow"
task :all_slow do
  %w(all slow).each do |t|
    Rake::Task[t].invoke
  end
end
