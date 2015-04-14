module AWSSupport
  module DeepMatcher
    #
    # If a module implements this, it signifies that
    #
    module MatchableArray

      #
      # TODO allow the user to return a new object that actually implements the
      # enumerable, in case the class in question is non-standard.
      #

      def self.matchable_classes
        @matchable_classes ||= []
      end

      def self.===(other)
        return true if matchable_classes.any? { |c| c === other }
        return true if Enumerable === other && !(Struct === other)
        super
      end
    end
  end
end
