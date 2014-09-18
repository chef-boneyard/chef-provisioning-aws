$:.unshift(File.dirname(__FILE__) + '/lib')
require 'chef_metal_aws/version'

Gem::Specification.new do |s|
  s.name = 'chef-metal-aws'
  s.version = ChefMetalAWS::VERSION
  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ['README.md', 'LICENSE' ]
  s.summary = 'Provisioner for creating aws containers in Chef Metal.'
  s.description = s.summary
  s.author = 'John Ewart'
  s.email = 'jewart@getchef.com'
  s.homepage = 'https://github.com/opscode/chef-metal-aws'

  s.add_dependency 'chef'
  s.add_dependency 'chef-metal', '~> 0.9'
  s.add_dependency 'aws-sdk'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rake'

  s.bindir       = "bin"
  s.executables  = %w( )

  s.require_path = 'lib'
  s.files = %w(Rakefile LICENSE README.md) + Dir.glob("{distro,lib,tasks,spec}/**/*", File::FNM_DOTMATCH).reject {|f| File.directory?(f) }
end
