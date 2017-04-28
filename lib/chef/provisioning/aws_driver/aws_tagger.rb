require 'retryable'

module Chef::Provisioning::AWSDriver
# Include this module on a class or instance that is responsible for tagging
# itself.  Fill in the hook methods so it knows how to tag itself.
class AWSTagger
  extend Forwardable

  attr_reader :action_handler

  def initialize(tagging_strategy, action_handler)
    @tagging_strategy = tagging_strategy
    @action_handler = action_handler
  end

  def_delegators :@tagging_strategy, :desired_tags, :current_tags, :set_tags, :delete_tags

  def converge_tags
    if desired_tags.nil?
      Chef::Log.debug "aws_tags not provided, nothing to converge"
      return
    end

    # Duplication and normalization
    # ::Aws::EC2::Errors::InvalidParameterValue: Tag value cannot be null. Use empty string instead.
    n_desired_tags = Hash[desired_tags.map {|k,v| [k.to_s, v.to_s]}]
    n_current_tags = Hash[current_tags.map {|k,v| [k.to_s, v.to_s]}]

    tags_to_set = n_desired_tags.reject {|k,v| n_current_tags[k] && n_current_tags[k] == v}
    tags_to_delete = n_current_tags.keys - n_desired_tags.keys
    # We don't want to delete `Name`, just all other tags
    # Tag keys and values are case sensitive - `Name` is special because it
    # shows as the name in the console
    tags_to_delete.delete('Name')

    # Tagging frequently fails so we retry with an exponential backoff, a maximum of 10 seconds
    Retryable.retryable(
      :tries => 20,
      :sleep => lambda { |n| [2**n, 10].min },
      :on => [::Aws::EC2::Errors, Aws::S3::Errors, ::Aws::S3::Errors::ServiceError,]
    ) do |retries, exception|
      if retries > 0
        Chef::Log.info "Retrying the tagging, previous try failed with #{exception.inspect}"
      end
      unless tags_to_set.empty?
        action_handler.perform_action "creating tags #{tags_to_set}" do
          set_tags(tags_to_set)
        end
        tags_to_set = []
      end
      unless tags_to_delete.empty?
        action_handler.perform_action "deleting tags #{tags_to_delete}" do
          delete_tags(tags_to_delete)
        end
        tags_to_delete = []
      end
    end
  end

end
end
