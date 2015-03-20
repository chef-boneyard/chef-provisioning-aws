require 'cheffish/rspec/chef_run_support'
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
      self.driver = aws_driver

      module_eval(&block)

      after :example do
        destroy_resources(created_during_test)
      end
    end
  end

  module WithAWSClassMethods
    attr_accessor :driver
    attr_reader :created_during_context

    def ensure_resources_get_destroyed
      if !created_during_context
        @created_during_context = []

        context = self

        after :context do
          destroy_resources(context.created_during_context)
        end
      end
    end

    #
    # Support using aws_* resources directly (to predeclare things)
    #
    Chef::Provisioning::AWSDriver::Resources.constants.each do |resource_class|
      resource_class = Chef::Provisioning::AWSDriver::Resources.const_get(resource_class)
      module_eval <<-EOM, __FILE__, __LINE__+1
        attr_reader :#{resource_class.aws_sdk_option_name}

        def #{resource_class.resource_name}(*args, &block)
          ensure_resources_get_destroyed

          driver = self.driver
          context = self
          before :context do
            created_during_context = context.created_during_context
            resource = nil
            run_recipe do
              with_driver driver
              resource = #{resource_class.resource_name}(*args, &block)
              if resource.action != :destroy && resource.action != :nothing
                created_during_context << resource
              end
            end
            @#{resource_class.aws_sdk_option_name} = resource
            resource
          end
        end
      EOM
    end
  end

  module WithAWSInstanceMethods
    def created_during_test
      @created_during_test ||= []
    end

    def driver
      self.class.driver
    end

    #
    # Support using aws_* resources directly (to predeclare things)
    #
    Chef::Provisioning::AWSDriver::Resources.constants.each do |resource_class|
      resource_class = Chef::Provisioning::AWSDriver::Resources.const_get(resource_class)
      module_eval <<-EOM, __FILE__, __LINE__+1
        def #{resource_class.aws_sdk_option_name}
          if defined?(@#{resource_class.aws_sdk_option_name})
            @#{resource_class.aws_sdk_option_name}
          else
            self.class.#{resource_class.aws_sdk_option_name}
          end
        end

        def #{resource_class.resource_name}(*args, &block)
          created_during_test = self.created_during_test
          driver = self.driver
          resource = nil
          run_recipe do
            with_driver driver
            resource = #{resource_class.resource_name}(*args, &block)
            if resource.action != :destroy && resource.action != :nothing
              created_during_test << resource
            end
          end
          @#{resource_class.aws_sdk_option_name} = resource
          resource
        end
      EOM
    end

    def destroy_resources(resources)
      if resources
        while resource = resources.pop
          begin
            puts "Destroying #{resource} ..."
            reset_chef_client
            driver = self.driver
            run_recipe do
              with_driver driver
              public_send(resource.resource_name, resource.name) { action :destroy }
            end
          rescue
            puts "Error #{$!} destroying #{resource}!  Sleeping 1s and retrying ..."
            sleep 1
            retry
          end
        end
      end
    end
  end
end

RSpec::Matchers.define :cause_an_update do
  match do |block|
    reset_chef_client
    resource = block.call
    expect(chef_run).to have_updated(resource.to_s, :create)
    true
  end

  supports_block_expectations
end

RSpec::Matchers.define :be_up_to_date do
  match do |block|
    reset_chef_client
    resource = block.call
    expect(chef_run).not_to have_updated(resource.to_s, :create)
    true
  end

  supports_block_expectations
end

RSpec::Matchers.define :be_idempotent do
  match do |block|
    reset_chef_client
    resource = block.call
    expect(chef_run).not_to have_updated(resource.to_s, :create)
    true
  end

  supports_block_expectations
end
