$LOAD_PATH.unshift(File.dirname(__FILE__) + "/lib")
require "chef/provisioning/aws_driver/version"

Gem::Specification.new do |s|
  s.name = "chef-provisioning-aws"
  s.version = Chef::Provisioning::AWSDriver::VERSION
  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ["README.md", "LICENSE"]
  s.summary = "Provisioner for creating aws containers in Chef Provisioning."
  s.description = s.summary
  s.author = "Tyler Ball"
  s.email = "tball@chef.io"
  s.homepage = "https://github.com/chef/chef-provisioning-aws"
  s.license = "Apache-2.0"

  s.required_ruby_version = ">= 2.1.9"

  s.add_dependency "chef-provisioning", ">= 1.0", "< 3.0"

  # all currently supported AWS services
  s.add_dependency "aws-sdk-core", [">= 3.0", "< 4.0"]
  s.add_dependency "aws-sdk-ec2", [">= 1.42.0", "< 2.0"]
  s.add_dependency "aws-sdk-s3", [">= 1.17.0", "< 2.0"]
  s.add_dependency "aws-sdk-rds", [">= 1.0", "< 4.0"]
  s.add_dependency "aws-sdk-route53", [">= 1.0", "< 4.0"]
  s.add_dependency "aws-sdk-autoscaling", [">= 1.0", "< 4.0"]
  s.add_dependency "aws-sdk-cloudwatch", [">= 1.0", "< 4.0"]
  s.add_dependency "aws-sdk-cloudsearch", [">= 1.0", "< 4.0"]
  s.add_dependency "aws-sdk-cloudsearchdomain", [">= 1.0", "< 4.0"]
  s.add_dependency "aws-sdk-elasticache", [">= 1.0", "< 4.0"]
  s.add_dependency "aws-sdk-iam", [">= 1.0", "< 4.0"]
  s.add_dependency "aws-sdk-opsworks", [">= 1.0", "< 4.0"]
  s.add_dependency "aws-sdk-sns", [">= 1.0", "< 4.0"]
  s.add_dependency "aws-sdk-sqs", [">= 1.0", "< 4.0"]

  s.add_dependency "retryable", "~> 2.0", ">= 2.0.1"
  s.add_dependency "ubuntu_ami", "~> 0.4", ">= 0.4.1"

  s.bindir       = "bin"
  s.executables  = %w{}

  s.require_path = "lib"
  s.files = %w{Gemfile Rakefile LICENSE README.md} + Dir.glob("*.gemspec") +
    Dir.glob("{distro,lib,tasks,spec}/**/*", File::FNM_DOTMATCH).reject { |f| File.directory?(f) }
end
