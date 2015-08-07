require 'rspec/matchers'
require 'chef/provisioning'
require 'aws_support/deep_matcher'

module AWSSupport
  module Matchers
    class DestroyAnAWSObject
      include RSpec::Matchers::Composable
      include AWSSupport::DeepMatcher

      def initialize(example, resource_class, name)
        @example = example
        @resource_class = resource_class
        @name = name

        # Grab the "before" value
        resource = resource_class.new(name, nil)
        resource.driver example.driver
        resource.managed_entry_store Chef::Provisioning.chef_managed_entry_store
        @had_initial_value = !resource.aws_object.nil?
      end

      attr_reader :example
      attr_reader :resource_class
      attr_reader :name
      def resource_name
        @resource_class.resource_name
      end
      attr_reader :had_initial_value

      def match_failure_messages(recipe)
        differences = []

        if !had_initial_value
          differences << "expected recipe to delete #{resource_name}[#{name}], but the AWS object did not exist before recipe ran!"
          return differences
        end

        # Converge
        begin
          recipe.converge unless recipe.converged?
        rescue
          differences += [ "error trying to delete #{resource_name}[#{name}]!\n#{($!.backtrace.map { |line| "- #{line}\n" } + [ recipe.output_for_failure_message ]).join("")}" ]
        end

        # Check whether the recipe caused an update or not
        differences += match_values_failure_messages(example.be_updated, recipe, "recipe")

        # Check for object existence and properties
        resource = resource_class.new(name, nil)
        resource.driver example.driver
        resource.managed_entry_store Chef::Provisioning.chef_managed_entry_store
        aws_object = resource.aws_object

        # Check existence
        differences << "#{resource_name}[#{name}] was not deleted!" unless aws_object.nil?

        differences
      end
    end
  end
end
