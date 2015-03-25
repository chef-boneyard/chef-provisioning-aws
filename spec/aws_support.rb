#
# Provides a `with_aws` method that when used in your tests will create a new
# context pointed at the user's chosen driver, and helper methods to create
# AWS objects and clean them up.
#
module AWSSupport
  require 'cheffish/rspec/chef_run_support'
  def self.extended(other)
    other.extend Cheffish::RSpec::ChefRunSupport
  end

  require 'chef/provisioning/aws_driver'
  require 'aws_support/matchers/create_an_aws_object'
  require 'aws_support/matchers/update_an_aws_object'
  require 'chef/provisioning/aws_driver/resources'
  require 'aws_support/aws_resource_run_wrapper'

  # Add AWS to the list of objects which can be matched against a Hash or Array
  require 'aws'
  require 'aws_support/deep_matcher/matchable_object'
  require 'aws_support/deep_matcher/matchable_array'
  DeepMatcher::MatchableObject.matchable_classes << proc { |o| o.class.name =~ /^AWS::EC2($|::)/ }
  DeepMatcher::MatchableArray.matchable_classes  << AWS::Core::Data::List

  def with_aws(description, *tags, &block)
    aws_driver = Chef::Provisioning.driver_for_url(ENV['AWS_TEST_DRIVER'])

    context_block = proc do
      extend WithAWSClassMethods
      include WithAWSInstanceMethods

      @@driver = aws_driver
      def self.driver
        @@driver
      end

      module_eval(&block)
    end

    if ENV['AWS_TEST_DRIVER']
      context description, *tags, &context_block
    else
#       warn <<EOM
# --------------------------------------------------------------------------------------------------------------------------
# AWS_TEST_DRIVER not set ... cannot run AWS test.  Set AWS_TEST_DRIVER=aws or aws:profile:region to run tests that hit AWS.
# --------------------------------------------------------------------------------------------------------------------------
# EOM
      skip "AWS_TEST_DRIVER not set ... cannot run AWS tests.  Set AWS_TEST_DRIVER=aws or aws:profile:region to run tests that hit AWS." do
        context description, *tags, &context_block
      end
    end
  end

  module WithAWSClassMethods
    def chef_config
      { driver: driver }
    end

    instance_eval do
      #
      # Create a context-level method for each AWS resource:
      #
      # with_aws do
      #   context 'mycontext' do
      #     aws_vpc 'myvpc' do
      #       ...
      #     end
      #   end
      # end
      #
      # Creates the AWS thing when the first example in the context runs.
      # Destroys it after the last example in the context runs.  Objects created
      # in the order declared, and destroyed in reverse order.
      #
      Chef::Provisioning::AWSDriver::Resources.constants.each do |resource_class|
        resource_class = Chef::Provisioning::AWSDriver::Resources.const_get(resource_class)
        resource_name = resource_class.resource_name
        # def aws_vpc(name, &block)
        define_method(resource_name) do |name, &block|
          # def myvpc
          #   @@myvpc
          # end
          instance_eval do
            define_method(name) { class_variable_get(:"@@#{name}") }
          end
          module_eval do
            define_method(name) { self.class.class_variable_get(:"@@#{name}") }
          end

          resource = nil

          before :context do
            resource = AWSResourceRunWrapper.new(self, resource_name, name, &block)
            # @myvpc = resource
            begin
              self.class.class_variable_set(:"@@#{name}", resource.resource)
            rescue NameError
            end
            resource.converge
          end

          after :context do
            resource.destroy if resource
          end
        end
      end
    end
  end

  module WithAWSInstanceMethods
    def self.included(context)
      context.module_eval do
        # Destroy any objects we know got created during the test
        after :example do
          created_during_test.reverse_each do |resource_name, name|
            (recipe do
              public_send(resource_name, name) do
                action :purge
              end
            end).converge
          end
        end
      end
    end

    #
    # expect_recipe { }.to create_an_aws_vpc
    # expect_recipe { }.to update_an_aws_security_object
    #
    Chef::Provisioning::AWSDriver::Resources.constants.each do |resource_class|
      resource_class = Chef::Provisioning::AWSDriver::Resources.const_get(resource_class)
      resource_name = resource_class.resource_name
      define_method("update_an_#{resource_name}") do |name, expected_updates|
        AWSSupport::Matchers::UpdateAnAWSObject.new(self, resource_class, name, expected_updates)
      end
      define_method("create_an_#{resource_name}") do |name, expected_values|
        AWSSupport::Matchers::CreateAnAWSObject.new(self, resource_class, name, expected_values)
      end
    end

    def chef_config
      { driver: driver }
    end

    def created_during_test
      @created_during_test ||= []
    end

    def default_vpc
      @default_vpc ||= driver.ec2.vpcs.filter('isDefault', 'true').first
    end

    def driver
      self.class.driver
    end
  end

end
