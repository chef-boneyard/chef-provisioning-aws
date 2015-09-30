$:.unshift(File.dirname(__FILE__) + '/lib')
require 'chef/provisioning/aws_driver/version'

Gem::Specification.new do |s|
  s.name = 'chef-provisioning-aws'
  s.version = Chef::Provisioning::AWSDriver::VERSION
  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ['README.md', 'LICENSE' ]
  s.summary = 'Provisioner for creating aws containers in Chef Provisioning.'
  s.description = s.summary
  s.author = 'John Ewart'
  s.email = 'jewart@getchef.com'
  s.homepage = 'https://github.com/opscode/chef-provisioning-aws'

  s.add_dependency 'chef-provisioning', '~> 1.4'

  s.add_dependency 'aws-sdk-v1', '>= 1.59.0'
  s.add_dependency 'aws-sdk', '~> 2.1'
  s.add_dependency 'retryable', '~> 2.0.1'
  s.add_dependency 'ubuntu_ami', '~> 0.4.1'

  # chef-zero is only a development dependency because we leverage its RSpec support
  s.add_development_dependency 'chef-zero', '~> 4.2'
  s.add_development_dependency 'chef', '~> 12.4'
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'pry-byebug'
  s.add_development_dependency 'pry-stack_explorer'

  s.bindir       = "bin"
  s.executables  = %w( )

  s.require_path = 'lib'
  s.files = %w(Gemfile Rakefile LICENSE README.md) + Dir.glob("{distro,lib,tasks,spec}/**/*", File::FNM_DOTMATCH).reject {|f| File.directory?(f) }
end
