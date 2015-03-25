module AWSSupport
  module DeepMatcher
    module MatchValuesFailureMessages

      require 'rspec/matchers'
      require 'rspec/matchers/composable'
      require 'aws_support/deep_matcher'
      require 'aws_support/deep_matcher/matchable_object'
      require 'aws_support/deep_matcher/matchable_array'

      protected

      def match_values_failure_messages(expected, actual, identifier=nil)
        if DeepMatcher === expected
          return expected.match_failure_messages(actual, identifier)
        elsif RSpec::Matchers::Composable === expected
          if !expected.matches?(actual)
            return [ expected.failure_message ]
          else
            return []
          end
        elsif Hash === expected
          return match_hashes_failure_messages(expected, actual, identifier) if Hash === actual
          return match_hash_and_object_failure_messages(expected, actual, identifier) if MatchableObject === actual
        elsif Array === expected
          return match_arrays_failure_messages(expected, actual, identifier) if MatchableArray === actual
        end

        if values_match?(expected, actual)
          []
        elsif expected.respond_to?(:failure_message)
          [ "#{identifier ? "#{identifier}: " : ""}#{expected.failure_message}" ]
        else
          [ "#{identifier ? "#{identifier}: " : ""}expected #{description_of(expected)}, but actual value was #{actual.inspect}" ]
        end
      end

      def match_hashes_failure_messages(expected_hash, actual_hash, identifier)
        result = []

        expected_hash.all? do |expected_key, expected_value|
          missing_value = false
          actual_value = actual_hash.fetch(expected_key) do
            result << "expected #{identifier || "hash"}[#{expected_key.inspect}] to #{description_of(expected_value)}, but it was missing entirely from the hash"
            missing_value = true
          end
          unless missing_value
            result += match_values_failure_messages(expected_value, actual_value, "#{identifier}[#{expected_key.inspect}]")
          end
        end

        result
      end

      #
      # Match arrays using Diff::LCS to determine which elements correspond to
      # which.
      #
      def match_arrays_failure_messages(expected_list, actual_list, identifier)
        result = [ "#{identifier || "value"} is different from expected!  Differences:" ]

        different = false

        expected_list = expected_list.map { |v| ExpectedValue.new(v) }
        Diff::LCS.sdiff(expected_list, actual_list) do |change|
          case change.action
          when '='
            messages = [ change.new_element.inspect ]
          when '+'
            messages = [ change.new_element.inspect ]
            different = true
          when '-'
            messages = [ change.old_element.description ]
            different = true
          when '!'
            messages = change.old_element.failure_messages(change.new_element)
            different = true
          else
            raise "Unknown operator returned from sdiff: #{op}"
          end
          op = change.action
          op = ' ' if op == '='
          result += messages.flat_map { |m| m.split("\n") }.map { |m| "#{op} #{m}" }
        end
        different ? result : []
      end

      def match_hash_and_object_failure_messages(expected_hash, actual_object, identifier)
        result = []

        expected_hash.all? do |expected_key, expected_value|
          # 'a.b.c' => 1 -> { a: { b: { c: 1 }}}
          names = expected_key.to_s.split('.')
          if names.size > 1
            expected_key = names.shift
            while !names.empty?
              expected_value = { names.pop => expected_value }
            end
          end

          # Grab the actual value from the object
          begin
            actual_value = actual_object.send(expected_key)
          rescue NoMethodError
            if !actual_value.respond_to?(expected_key)
              result << "#{identifier || "hash"}[#{expected_key.inspect}] is missing, expected value #{description_of(expected_value)}"
              next
            else
              raise
            end
          end

          # Check if the values are different
          result += match_values_failure_messages(expected_value, actual_value, "#{identifier}.#{expected_key}")
        end

        result
      end

      #
      # Handles == by calling match (used for Diff::LCS to do its magic and still
      # work with rspec)
      #
      class ExpectedValue
        include RSpec::Matchers::Composable
        include MatchValuesFailureMessages

        def initialize(value)
          @value = value
        end
        attr_reader :value

        def failure_messages(actual)
          @failure_messages[actual]
        end

        def ==(actual)
          @failure_messages ||= {}
          @failure_messages[actual] ||= match_values_failure_messages(value, actual)
          @failure_messages[actual].empty?
        end
      end
    end
  end
end
