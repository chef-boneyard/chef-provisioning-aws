module AWSSupport
  module DeepMatcher
    #
    # This gets mixed into RSpec::Support::FuzzyMatch, adding the ability to
    # fuzzy match objects against hashes, a la:
    #
    # values_match({ a: 1, b: 2, 'c.d.e' => 3 },
    #   <non-hash object with a, b and c methods>
    # end
    #
    module FuzzyMatchObjects

      require 'rspec/support/fuzzy_matcher'
      require 'aws_support/deep_matcher/matchable_object'
      require 'aws_support/deep_matcher/matchable_array'

      def values_match?(expected, actual)
        if Hash === expected
          return hash_and_object_match?(expected, actual) if MatchableObject === actual
        elsif Array === expected
          return arrays_match?(expected, actual) if MatchableArray === actual
        end

        super
      end

      def hash_and_object_match?(expected, actual)
        expected_hash.all? do |expected_key, expected_value|
          # 'a.b.c'  => 1 -> { 'a' => { 'b' => { 'c' => 1 } } }
          # :"a.b.c" => 1 -> { :a  => { :b  => { :c  => 1 } } }
          names = expected_key.to_s.split('.')
          if names.size > 1
            expected_key = expected_key.is_a?(Symbol) ? names.shift.to_sym : names.shift
            while !names.empty?
              expected_value = { names.pop => expected_value }
            end
          end

          # Grab the actual value from the object
          begin
            actual_value = actual_object.send(expected_key)
          rescue NoMethodError
            if !actual_value.respond_to?(expected_key)
              return false
            else
              raise
            end
          end

          return false if !values_match?(expected, actual)
        end

        true
      end
    end
  end
end
