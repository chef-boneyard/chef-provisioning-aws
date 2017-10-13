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
  require 'aws_support/matchers/destroy_an_aws_object'
  require 'aws_support/matchers/have_aws_object_tags'
  require 'aws_support/matchers/match_an_aws_object'
  require 'aws_support/delayed_stream'
  require 'chef/provisioning/aws_driver/resources'
  require 'aws_support/aws_resource_run_wrapper'

  # Add AWS to the list of objects which can be matched against a Hash or Array
  require 'aws-sdk'
  require 'aws_support/deep_matcher/matchable_object'
  require 'aws_support/deep_matcher/matchable_array'
  DeepMatcher::MatchableObject.matchable_classes << proc { |o| o.class.name =~ /^(AWS|Aws)::(AutoScaling|EC2|ELB|IAM|S3|RDS|CloudSearch|CloudWatch|Route53|ElasticsearchService)($|::)/ }
  DeepMatcher::MatchableArray.matchable_classes  #<< AWS::Core::Data::List

  def purge_all
    before :all do
      driver = self.driver
      recipe do
        vpcs = driver.ec2.describe_vpcs({filters: [{name: "tag-value", values: ["test_vpc"]}]})[:vpcs]
        vpcs.each do |vpc|
          aws_vpc vpc.vpc_id do
            action :purge
          end
        end
        aws_key_pair 'test_key_pair' do
          action :purge
        end
      end.converge
    end
  end

  def setup_public_vpc
    aws_vpc 'test_vpc' do
      cidr_block '10.0.0.0/16'
      internet_gateway true
      enable_dns_hostnames true
      # TODO : uncomment this when fix main routes in aws_vpc resource as per new version
      # main_routes '0.0.0.0/0' => :internet_gateway
    end

    aws_key_pair 'test_key_pair' do
      allow_overwrite true
    end

    before :context do
      # TODO : Need to fix below line as per version two commenting out for now since its failing and not able to proceed for other specs
      image = driver.ec2.describe_images({filters: [{name: 'name', values: ['test_machine_image']}]}).first
      image.delete unless image

      default_sg = test_vpc.aws_object.security_groups({filters: [{name: 'group-name', values: ['default']}]}).first
      recipe do
        aws_security_group default_sg do
          inbound_rules '0.0.0.0/0' => 22
        end
      end.converge
    end

    aws_security_group 'test_security_group' do
      vpc 'test_vpc'
      inbound_rules '0.0.0.0/0' => [ 22, 80 ]
      outbound_rules [ 22, 80 ] => '0.0.0.0/0'
    end

    azs = driver.ec2_client.describe_availability_zones.availability_zones.map {|r| r.zone_name}
    aws_subnet 'test_public_subnet' do
      vpc 'test_vpc'
      cidr_block '10.0.0.0/24'
      map_public_ip_on_launch true
      availability_zone azs.first
    end
  end

  def with_aws(description, *tags, &block)
    aws_driver = nil
    context_block = proc do
      extend WithAWSClassMethods
      include WithAWSInstanceMethods

      @@driver = aws_driver
      def self.driver
        @@driver
      end

      module_eval(&block)
    end

    if ENV['AWS_TEST_DRIVER']  && !ENV['AWS_TEST_DRIVER'].empty?
      aws_driver = Chef::Provisioning.driver_for_url(ENV['AWS_TEST_DRIVER'])
      when_the_repository "exists #{description ? "and #{description}" : ""}", *tags, &context_block
    else
      skip "AWS_TEST_DRIVER not set ... cannot run AWS tests.  Set AWS_TEST_DRIVER=aws or aws:profile:region to run tests that hit AWS." do
        context description, *tags, &context_block
      end
    end
  end

  module WithAWSClassMethods
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
      aws_resources = Chef::Provisioning::AWSDriver::Resources.constants
      aws_resources.map! {|r| Chef::Provisioning::AWSDriver::Resources.const_get(r) }

      aws_resources += [Chef::Resource::Machine, Chef::Resource::MachineImage, Chef::Resource::MachineBatch, Chef::Resource::LoadBalancer]
      aws_resources.each do |resource_class|
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
            begin
              resource.converge
            rescue
              puts "ERROR #{$!}"
              puts $!.backtrace.join("\n")
              raise
            end
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
        after :example do
          # Close up delayed streams so they don't print out their garbage later in the run
          unless chef_config[:include_output_after_example]
            delayed_streams.each { |s| s.close }
          end

          # Destroy any objects we know got created during the test
          created_during_test.reverse_each do |resource_name, name|
            begin
              (recipe do
                public_send(resource_name, name) do
                  action :purge
                end
              end).converge
            rescue ::Chef::Exceptions::ValidationFailed
              (recipe do
                public_send(resource_name, name) do
                  action :destroy
                end
              end).converge
            end
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
      define_method("update_an_#{resource_name}") do |name, expected_updates={}, &block|
        AWSSupport::Matchers::UpdateAnAWSObject.new(self, resource_class, name, expected_updates, block)
      end
      define_method("create_an_#{resource_name}") do |name, expected_values={}, &block|
        AWSSupport::Matchers::CreateAnAWSObject.new(self, resource_class, name, expected_values, block)
      end
      define_method("have_#{resource_name}_tags") do |name, expected_tags={}|
        AWSSupport::Matchers::HaveAWSObjectTags.new(self, resource_class, name, expected_tags)
      end
      define_method("destroy_an_#{resource_name}") do |name, expected_values={}|
        AWSSupport::Matchers::DestroyAnAWSObject.new(self, resource_class, name)
      end
      define_method("match_an_#{resource_name}") do |name, expected_values={}, &block|
        AWSSupport::Matchers::MatchAnAWSObject.new(self, resource_class, name, expected_values, block)
      end
    end

    def chef_config
      @chef_config ||= {
        driver:       driver,
        stdout:       delayed_stream(delay_before_streaming, STDOUT),
        stderr:       delayed_stream(delay_before_streaming, STDERR),
        log_location: delayed_stream(delay_before_streaming_logs, STDOUT),
        log_level:    :info
      }
    end

    def delayed_streams
      @delayed_streams ||= []
    end

    def delayed_stream(delay, stream)
      stream = DelayedStream.new(delay, stream)
      delayed_streams << stream
      stream
    end

    # Override in tests if you want different numbers
    def delay_before_streaming_logs
      30
    end

    def delay_before_streaming
      10
    end

    def created_during_test
      @created_during_test ||= []
    end

    def default_vpc
      @default_vpc ||= driver.ec2.describe_vpcs({filters: [{name: "isDefault", values: ["true"]}]})[:vpcs].first
    end

    def driver
      self.class.driver
    end
  end

end
