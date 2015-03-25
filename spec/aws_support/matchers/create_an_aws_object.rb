require 'rspec/matchers'
require 'chef/provisioning'
require 'aws_support/deep_matcher'

module AWSSupport
  module Matchers
    class CreateAnAWSObject
      include RSpec::Matchers::Composable
      include AWSSupport::DeepMatcher

      def initialize(rspec_context, resource_class, name, expected_values)
        @rspec_context = rspec_context
        @resource_class = resource_class
        @name = name
        @expected_values = expected_values
      end

      attr_reader :rspec_context
      attr_reader :resource_class
      attr_reader :name
      attr_reader :expected_values
      def resource_name
        @resource_class.resource_name
      end

      def match_failure_messages(recipe)
        differences = []

        # We want to record that it was created BEFORE the converge, so that
        # even if it fails, we destroy it.
        rspec_context.created_during_test << [ resource_name, name ]

        # Converge
        begin
          recipe.converge
        rescue
          differences += [ "error trying to create #{resource_name}[#{name}]!\n#{$!.backtrace.map { |line| "- #{line}\n" }.join("")}" ]
        end

        # Check whether the recipe caused an update or not
        differences += match_values_failure_messages(rspec_context.be_updated, recipe, "recipe")

        # Check for object existence and properties
        resource = resource_class.new(name, nil)
        resource.driver rspec_context.driver
        resource.managed_entry_store Chef::Provisioning.chef_managed_entry_store
        aws_object = resource.aws_object

        # Check existence
        if aws_object.nil?
          differences << "#{resource_name}[#{name}] was not created!"
        else
          differences += match_values_failure_messages(expected_values, aws_object, "#{resource_name}[#{name}]")
        end

        differences
      end
    end
  end
end
