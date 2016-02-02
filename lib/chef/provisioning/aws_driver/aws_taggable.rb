module Chef::Provisioning::AWSDriver
# This module is meant to be included in a resource that is taggable
# This will add the appropriate attribute that can be converged by the provider
# TODO it would be nice to not have two seperate modules (taggable/tagger)
#   and just have the provider decorate the resource or vice versa.  Complicated
#   by resources <-> providers being many-to-many.
module AWSTaggable

  def self.included(klass)
    # This should be a hash of tags to apply to the AWS object
    #
    # @param aws_tags [Hash] Should be a hash of keys & values to add.  Keys and values
    #        can be provided as symbols or strings, but will be stored in AWS as strings.
    klass.attribute :aws_tags, kind_of: Hash
  end

end
end
