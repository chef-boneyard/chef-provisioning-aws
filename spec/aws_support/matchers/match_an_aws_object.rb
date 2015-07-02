require 'rspec/matchers'
require 'chef/provisioning'
require 'aws_support/deep_matcher'

module AWSSupport
  module Matchers

    # This matcher doesn't try to validate that an example was created/updated/destroyed
    # it just checks that the object exists and posses the attributes you specify
    # It also doesn't clean up any aws objects so only use if the resource is defined outside
    # of an example block
    class MatchAnAWSObject
      include RSpec::Matchers::Composable
      include AWSSupport::DeepMatcher

      def initialize(example, resource_class, name, expected_values)
        @example = example
        @resource_class = resource_class
        @name = name
        @expected_values = expected_values
      end

      attr_reader :example
      attr_reader :resource_class
      attr_reader :name
      attr_reader :expected_values
      def resource_name
        @resource_class.resource_name
      end

      def match_failure_messages(recipe)
        differences = []

        # Converge
        begin
          recipe.converge
        rescue
          differences += [ "error trying to converge #{resource_name}[#{name}]!\n#{($!.backtrace.map { |line| "- #{line}\n" } + [ recipe.output_for_failure_message ]).join("")}" ]
        end

        # Check for object existence and properties
        resource = resource_class.new(name, nil)
        resource.driver example.driver
        resource.managed_entry_store Chef::Provisioning.chef_managed_entry_store
        aws_object = resource.aws_object

        # Check existence
        if aws_object.nil?
          differences << "#{resource_name}[#{name}] AWS object did not exist!"
        else
          differences += match_values_failure_messages(expected_values, aws_object, "#{resource_name}[#{name}]")
        end

        differences
      end
    end
  end
end
