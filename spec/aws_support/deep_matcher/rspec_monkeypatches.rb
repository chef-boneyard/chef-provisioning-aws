# FIRST thing we do in a desperate attempt to get our module in before RSpec loads

module AWSSupport
  module DeepMatcher
    module MatchValuesFailureMessages
    end
  end
end

module RSpec
  module Matchers
    module Composable
      include AWSSupport::DeepMatcher::MatchValuesFailureMessages
    end
  end
end

require 'aws_support/deep_matcher/match_values_failure_messages'
require 'rspec/matchers/composable'
require 'rspec/support/fuzzy_matcher'
require 'aws_support/deep_matcher/fuzzy_match_objects'

module RSpec::Support::FuzzyMatcher
  prepend AWSSupport::DeepMatcher::FuzzyMatchObjects
end
