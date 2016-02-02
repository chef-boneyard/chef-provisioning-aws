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
        resource = resource_class.new(name, recipe.client.run_context)
        resource.driver example.driver
        resource.managed_entry_store Chef::Provisioning.chef_managed_entry_store
        @aws_object = resource.aws_object

        # Check existence
        if @aws_object.nil?
          differences << "#{resource.to_s} did not exist!"
        else
          differences += match_hashes_failure_messages(expected_tags, aws_object_tags(resource), resource.to_s)
        end

        differences
      end

      private

      def aws_object_tags(resource)
        # Okay, its annoying to have to lookup the provider for a resource and duplicate a bunch of code here.
        # But I don't want to move the `converge_tags` method into the resource and until the resource & provider
        # are combined, this is my best idea.
        provider = resource.provider_for_action(:create)
        provider.aws_tagger.current_tags
      end

    end
  end
end
