require 'cheffish/rspec/chef_run_support'
require 'cheffish/rspec/recipe_run_wrapper'
require 'chef/provisioning/aws_driver'

module AWSSupport
  def self.extended(other)
    other.extend Cheffish::RSpec::ChefRunSupport
  end

  def with_aws(description, *tags, &block)
    if ENV['AWS_TEST_DRIVER']
      aws_driver = Chef::Provisioning.driver_for_url(ENV['AWS_TEST_DRIVER'])
    else
      tags << { skip: "AWS_TEST_DRIVER not set ... cannot run AWS test.  Set AWS_TEST_DRIVER=aws or aws:profile:region to run tests that hit AWS" }
    end

    context description, *tags do
      extend WithAWSClassMethods
      include WithAWSInstanceMethods

      @@driver = aws_driver
      def self.driver
        @@driver
      end

      module_eval(&block)
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
        # def aws_vpc(name, &block)
        define_method(resource_class.resource_name) do |name, &block|
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
            resource = AWSResourceRunWrapper.new(self, resource_class.resource_name, name, &block)
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
                action :destroy
              end
            end).converge
          end
        end
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

  class AWSResourceRunWrapper < Cheffish::RSpec::RecipeRunWrapper
    def initialize(rspec_context, resource_type, name, &properties)
      super(rspec_context.chef_config) do
        public_send(resource_type, name, &properties)
      end
      @rspec_context = rspec_context
      @resource_type = resource_type
      @name = name
      @properties = properties
    end

    attr_reader :rspec_context
    attr_reader :resource_type
    attr_reader :name

    def resource
      resources.first
    end

    def to_s
      "#{resource_type}[#{name}]"
    end

    def destroy
      resource_type = self.resource_type
      name = self.name
      rspec_context.run_recipe do
        public_send(resource_type, name) do
          action :destroy
        end
      end
    end

    def aws_object
      resource.aws_object
    end
  end
end


#
# Matchers for:
#
# - create_an_aws_security_group
# - create_an_aws_vpc
# etc.
#
# Checks if the object got created, then deletes the object at the end of the test.
#
Chef::Provisioning::AWSDriver::Resources.constants.each do |resource_class|
  resource_class = Chef::Provisioning::AWSDriver::Resources.const_get(resource_class)

  RSpec::Matchers.define :"create_an_#{resource_class.resource_name}" do |name, expected_properties|
    match do |recipe|
      @recipe = recipe

      # Converge
      recipe.converge
      expect(recipe).to be_updated

      resource = resource_class.new(name, nil)
      resource.driver driver
      resource.managed_entry_store Chef::Provisioning.chef_managed_entry_store
      aws_object = resource.aws_object

      # Check existence and properties
      if aws_object.nil?
        raise "#{resource.to_s} succeeded but was not created!"
      end

      created_during_test << [ resource_class.resource_name, name ]

      # Check to see if properties have the expected values
      @differences = {}
      expected_properties.each do |name, value|
        aws_value = aws_object.public_send(name)
        if !(aws_value === expected_properties[name])
          @differences[name] = aws_value
        end
      end

      @differences.empty?
    end

    failure_message {
      message = "#{@recipe} created an AWS object with unexpected values:\n"
      @differences.each do |name, value|
        message << "- expected #{name} to match #{expected_properties[name].inspect}, but the actual value was #{value.inspect}\n"
      end
      message << @recipe.output_for_failure_message
      message
    }
  end
end
