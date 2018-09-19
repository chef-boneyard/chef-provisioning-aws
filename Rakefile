require "bundler/gem_tasks"
require "rspec/core/rake_task"

task default: :spec

desc "run all non-integration specs"
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = "spec/**/*_spec.rb"
  # TODO: add back integration tests whenever we have strategy for keys
  spec.exclude_pattern = "spec/integration/**/*_spec.rb"
end

desc "run integration specs"
RSpec::Core::RakeTask.new(:integration, [:pattern]) do |spec, args|
  spec.pattern = args[:pattern] || "spec/integration/**/*_spec.rb"
  spec.rspec_opts = "-b"
end

desc "run :super_slow specs (machine/machine_image)"
RSpec::Core::RakeTask.new(:super_slow, [:pattern]) do |spec, args|
  spec.pattern = args[:pattern] || "spec/integration/**/*_spec.rb"
  spec.rspec_opts = "-b -t super_slow"
end

desc "run all specs, except :super_slow"
RSpec::Core::RakeTask.new(:all) do |spec|
  spec.pattern = "spec/**/*_spec.rb"
end

desc "run all specs, including :super_slow"
task :all_slow do
  %w{all slow}.each do |t|
    Rake::Task[t].invoke
  end
end

desc "travis specific task - runs CI integration tests (regular and super_slow in parallel) and sets up travis specific ENV variables"
task :travis, [:sub_task] do |_t, args|
  sub_task = args[:sub_task]
  if sub_task == "super_slow"
    pattern = "load_balancer_spec.rb,aws_route_table_spec.rb,machine_spec.rb,aws_eip_address_spec.rb" # This is a comma seperated list
    pattern = pattern.split(",").map { |p| "spec/integration/**/*#{p}" }.join(",")
  else
    pattern = "spec/integration/**/*_spec.rb"
  end
  Rake::Task[sub_task].invoke(pattern)
end

desc "travis task for machine_image tests - these take so long to run that we only run the first test"
RSpec::Core::RakeTask.new(:machine_image) do |spec|
  spec.pattern = "spec/integration/machine_image_spec.rb"
  spec.rspec_opts = "-b -t super_slow -e 'machine_image can create an image in the VPC'"
end

task :console do
  require "irb"
  require "irb/completion"
  ARGV.clear
  IRB.start
end

begin
  require "chefstyle"
  require "rubocop/rake_task"
  RuboCop::RakeTask.new(:chefstyle) do |task|
    task.options << "--display-cop-names"
  end
rescue LoadError
  puts "chefstyle gem is not installed"
end
