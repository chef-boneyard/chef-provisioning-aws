module AWSSupport
  module DeepMatcher
    #
    # If a module implements this, or is added to `matchable_classes`,
    # RSpec's `match` will match its attributes up to hashes a la:
    #
    # ```ruby
    # expect(my_object).to match({ a: 1, b: 2 })
    # ```
    #
    # Which will compare my_object.a to 1 and my_object.b to 2.
    #
    module MatchableObject

      def self.matchable_classes
        @matchable_classes ||= []
      end

      def self.===(other)
        return true if matchable_classes.any? { |c| c === other}
        super
      end
    end
  end
end
