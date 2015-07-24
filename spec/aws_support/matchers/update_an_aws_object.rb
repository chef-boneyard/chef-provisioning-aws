require 'rspec/matchers'
require 'aws_support/deep_matcher'

module AWSSupport
  module Matchers
    class UpdateAnAWSObject

      include RSpec::Matchers::Composable
      include AWSSupport::DeepMatcher

      require 'chef/provisioning'

      def initialize(example, resource_class, name, expected_updates)
        @example = example
        @resource_class = resource_class
        @name = name
        @expected_updates = expected_updates

        # Grab the "before" value
        resource = resource_class.new(name, nil)
        resource.driver example.driver
        resource.managed_entry_store Chef::Provisioning.chef_managed_entry_store
        @had_initial_value = !resource.aws_object.nil?
      end

      attr_reader :example
      attr_reader :resource_class
      attr_reader :name
      attr_reader :expected_updates
      def resource_name
        @resource_class.resource_name
      end
      attr_reader :had_initial_value

      def match_failure_messages(recipe)
        differences = []

        if !had_initial_value
          differences << "expected recipe to update #{resource_name}[#{name}], but the AWS object did not exist before recipe ran!"
          return differences
        end

        # Converge
        begin
          recipe.converge
        rescue
          differences += [ "error trying to update #{resource_name}[#{name}]!\n#{($!.backtrace.map { |line| "- #{line}\n" } + [ recipe.output_for_failure_message ]).join("")}" ]
        end

        # Check if the recipe actually caused an update
        differences += match_values_failure_messages(example.be_updated, recipe, "recipe")

        # Check if any properties that should have been updated, weren't
        resource = resource_class.new(name, nil)
        resource.driver example.driver
        resource.managed_entry_store Chef::Provisioning.chef_managed_entry_store
        aws_object = resource.aws_object

        # Check to see if properties have the expected values
        differences += match_values_failure_messages(expected_updates, aws_object, "#{resource_name}[#{name}]")

        differences
      end
    end
  end
end
