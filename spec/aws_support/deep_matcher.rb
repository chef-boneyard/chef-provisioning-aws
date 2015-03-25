module AWSSupport
  #
  # Include this and override `match_failure_messages`, and your class becomes
  # a matcher which will have `matches?` call `match_failure_messages` and
  # cache the result, which is then returned verbatim from failure_message.
  #
  module DeepMatcher

    require 'aws_support/deep_matcher/match_values_failure_messages'

    include MatchValuesFailureMessages

    def matches?(actual)
      @failure_messages = match_failure_messages(actual)
      @failure_messages.empty?
    end

    def failure_message
      @failure_messages.flat_map { |message| message.split("\n") }.join("\n")
    end

    def failure_message_when_negated
      "expected #{@actual.inspect} not to #{description}"
    end

    #
    # Return the failure message resulting from matching `actual`.  Meant to be
    # overridden in implementors.
    #
    # @param actual The actual value to compare against
    # @param identifier The name of the thing being compared (may not be passed,
    #                   in which case the class will choose an appropriate default.)
    #
    # @return A failure message, or empty string if it does not fail.
    #
    def match_failure_messages(actual, identifier='value')
      raise NotImplementedError, :match_failure_messages
    end
  end
end
