$LOAD_PATH.unshift(File.dirname(__FILE__) + "/lib")
require "chef/provisioning/aws_driver/version"

Gem::Specification.new do |s|
  s.name = "chef-provisioning-aws"
  s.version = Chef::Provisioning::AWSDriver::VERSION
  s.summary = "Provisioner for creating aws containers in Chef Provisioning."
  s.description = s.summary
  s.author = "Tyler Ball"
  s.email = "tball@chef.io"
  s.homepage = "https://github.com/chef/chef-provisioning-aws"
  s.license = "Apache-2.0"
  s.required_ruby_version = ">= 2.1.9"

  s.add_dependency "chef-provisioning", ">= 1.0", "< 3.0"

  s.add_dependency "aws-sdk", [">= 2.2.18", "< 3.0"]
  s.add_dependency "retryable", "~> 2.0", ">= 2.0.1"
  s.add_dependency "ubuntu_ami", "~> 0.4", ">= 0.4.1"

  s.require_path = "lib"
  s.files = %w{Gemfile Rakefile LICENSE} + Dir.glob("*.gemspec") +
    Dir.glob("{lib,spec}/**/*", File::FNM_DOTMATCH).reject { |f| File.directory?(f) }
end
