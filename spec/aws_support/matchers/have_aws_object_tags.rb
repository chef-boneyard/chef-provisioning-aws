require 'rspec/matchers'
require 'chef/provisioning'
require 'aws_support/deep_matcher'

module AWSSupport
  module Matchers
    class HaveAWSObjectTags
      include RSpec::Matchers::Composable
      include AWSSupport::DeepMatcher

      def initialize(example, resource_class, name, expected_tags)
        @example = example
        @resource_class = resource_class
        @name = name
        @expected_tags = expected_tags
      end

      attr_reader :example
      attr_reader :resource_class
      attr_reader :name
      attr_reader :expected_tags
      def resource_name
        @resource_class.resource_name
      end

      def match_failure_messages(recipe)
        differences = []

        # Check for object existence and properties
        resource = resource_class.new(name, nil)
        resource.driver example.driver
        resource.managed_entry_store Chef::Provisioning.chef_managed_entry_store
        @aws_object = resource.aws_object

        # Check existence
        if @aws_object.nil?
          differences << "#{resource_name}[#{name}] did not exist!"
        else
          differences += match_hashes_failure_messages(expected_tags, aws_object_tags, "#{resource_name}[#{name}]")
        end

        differences
      end

      private

      def aws_object_tags
        if @aws_object.is_a? AWS::ELB::LoadBalancer
          resp = @example.driver.elb.client.describe_tags load_balancer_names: [@aws_object.name]
          tags = {}
          resp.data[:tag_descriptions] && resp.data[:tag_descriptions].each do |td|
            td[:tags].each do |t|
              tags[t[:key]] = t[:value]
            end
          end
          tags
        else
          @aws_object.tags.to_h
        end
      end
    end
  end
end
