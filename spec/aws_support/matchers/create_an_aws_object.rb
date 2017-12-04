require 'rspec/matchers'
require 'chef/provisioning'
require 'aws_support/deep_matcher'

module AWSSupport
  module Matchers
    class CreateAnAWSObject
      include RSpec::Matchers::Composable
      include AWSSupport::DeepMatcher

      # @param custom_matcher [Block] A block with 1 argument that will be provided the aws_object
      def initialize(example, resource_class, name, expected_values, custom_matcher)
        @example = example
        @resource_class = resource_class
        @name = name
        @expected_values = expected_values
        @custom_matcher = custom_matcher
      end

      attr_reader :example
      attr_reader :resource_class
      attr_reader :name
      attr_reader :expected_values
      attr_reader :custom_matcher

      def resource_name
        @resource_class.resource_name
      end

      def match_failure_messages(recipe)
        differences = []

        # We want to record that it was created BEFORE the converge, so that
        # even if it fails, we destroy it.
        example.created_during_test << [ resource_name, name ]

        # Converge
        begin
          recipe.converge unless recipe.converged?
        rescue
          differences += [ "error trying to create #{resource_name}[#{name}]!\n#{($!.backtrace.map { |line| "- #{line}\n" } + [ recipe.output_for_failure_message ]).join("")}" ]
        end

        # Check whether the recipe caused an update or not
        differences += match_values_failure_messages(example.be_updated, recipe, "recipe")

        # Check for object existence and properties
        resource = resource_class.new(name, nil)
        resource.driver example.driver
        resource.managed_entry_store Chef::Provisioning.chef_managed_entry_store
        aws_object = resource.aws_object

        example.instance_exec aws_object, &custom_matcher if custom_matcher

        # We get response as a Struct for aws_cache_subnet_group resource.
        # Hence converting it into a hash.
        aws_object = aws_object.to_hash if resource_name == :aws_cache_subnet_group || resource_name == :aws_cache_cluster

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
