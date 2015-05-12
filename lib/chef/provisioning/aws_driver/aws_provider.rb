require 'chef/provider/lwrp_base'
require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/provisioning/aws_driver/aws_resource_with_entry'
require 'chef/provisioning/chef_managed_entry_store'
require 'chef/provisioning/chef_provider_action_handler'
require 'retryable'

module Chef::Provisioning::AWSDriver
class AWSProvider < Chef::Provider::LWRPBase
  use_inline_resources

  AWSResource = Chef::Provisioning::AWSDriver::AWSResource

  class StatusTimeoutError < TimeoutError
    def initialize(aws_object, initial_status, expected_status)
      super("timed out waiting for #{aws_object.id} status to change from #{initial_status.inspect} to #{expected_status.inspect}!")
    end
  end

  def action_handler
    @action_handler ||= Chef::Provisioning::ChefProviderActionHandler.new(self)
  end

  # All these need to implement whyrun
  def whyrun_supported?
    true
  end

  def region
    new_resource.driver.aws_config.region
  end

  #
  # Return the damned value from the block, not whatever weirdness converge_by
  # normally returns.
  #
  def converge_by(*args, &block)
    result = nil
    super(*args) do
      result = block.call
    end
    result
  end

  action :create do
    #
    # If the user specified an ID, get the object for it, and fail if it does not exist.
    #
    desired_driver = new_resource.driver
    desired_id = new_resource.public_send(new_resource.class.aws_id_attribute) if new_resource.class.aws_id_attribute
    if desired_id
      aws_object = new_resource.class.get_aws_object(desired_id, resource: new_resource)
    end

    #
    # If Chef has already associated the object with an AWS ID, check if it's
    # the same as the desired AWS ID.
    #
    if new_resource.is_a?(AWSResourceWithEntry)
      entry_driver, entry_id, entry = new_resource.get_id_from_managed_entry
      if entry_id
        if desired_id

          #
          # We have both a desired ID and an entry ID.  Find out whether they
          # match and warn if they don't (because we're going to reassociate and
          # update the *desired* AWS thing.).
          #
          if desired_driver.driver_url == entry_driver.driver_url && desired_id == entry_id
            Chef::Log.debug "#{new_resource.to_s} is already associated with #{entry_id} in #{entry_driver.driver_url}"
          else
            Chef::Log.warn "#{new_resource.to_s} is currently associated with #{entry_id} in #{entry_driver.driver_url}, but the desired ID is #{desired_id} in #{new_resource.driver.driver_url}!  Will associate with new desired ID #{desired_id}."
          end

        else

          #
          # If we don't have desired (common case), we'll update the existing
          # resource or create a new one if it's been deleted.
          #
          aws_object = new_resource.class.get_aws_object(entry_id, driver: entry_driver, resource: new_resource, required: false)
          if aws_object
            Chef::Log.debug "#{new_resource.to_s} is currently associated with #{entry_id} in #{entry_driver.driver_url}."
          else
            Chef::Log.warn "#{new_resource.to_s} is currently associated with #{entry_id} in #{entry_driver.driver_url}, but it does not exist!  We will create a new one to replace it."
          end
        end

      else

        #
        # If we don't currently have an AWS ID associated with this resource, we
        # will either associate the desired one, or create a new one.
        #
        if desired_id
          Chef::Log.debug "#{new_resource.to_s} is not yet associated with anything.  Associating with desired object #{desired_id} in #{desired_driver.driver_url}."
        else
          Chef::Log.debug "#{new_resource.to_s} is not yet associated with anything.  Creating a new one in #{desired_driver.driver_url} ..."
        end
      end

    else

      #
      # If it does not support storing IDs in Chef at all, just grab the existing
      # object and we'll update (or not) based on that.
      #
      aws_object ||= new_resource.aws_object

    end

    #
    # Actually update or create the AWS object
    #
    if aws_object
      action, new_obj = update_aws_object(aws_object)
      if action == :replaced_aws_object
        aws_object = new_obj
      end
    else
      aws_object = create_aws_object
    end

    converge_tags(aws_object)

    #
    # Associate the managed entry with the AWS object
    #
    if new_resource.is_a?(AWSResourceWithEntry)
      new_resource.save_managed_entry(aws_object, action_handler, existing_entry: entry)
    end

    aws_object
  end

  # TODO having a @purging flag feels weird
  action :purge do
    @purging = true
    begin
      action_destroy
    ensure
      @purging = false
    end
  end

  attr_reader :purging

  action :destroy do
    desired_driver = new_resource.driver
    desired_id = new_resource.public_send(new_resource.class.aws_id_attribute) if new_resource.class.aws_id_attribute

    #
    # If the user specified an ID, delete THAT; do NOT delete the associated object.
    #
    if desired_id
      aws_object = new_resource.class.get_aws_object(desired_id, resource: new_resource, required: false)
      if aws_object
        Chef::Log.debug "#{new_resource.to_s} provided #{new_resource.class.aws_id_attribute} #{desired_id} in #{desired_driver.driver_url}.  Will delete."
      end
    end

    #
    # Managed entries are looked up by ID.
    #
    if new_resource.is_a?(AWSResourceWithEntry)
      entry_driver, entry_id, entry = new_resource.get_id_from_managed_entry
      if entry_id
        if desired_id && (desired_id != entry_id || desired_driver.driver_url != entry_driver.driver_url)
          if new_resource.class.get_aws_object(entry_id, driver: entry_driver, resource: new_resource, required: false)
            # If the desired ID / driver differs from the entry, don't delete.  We
            # certainly can't delete the AWS object itself, and we don't *want* to
            # delete the association, because the expectation is that after doing a
            # delete, you should be able to create a new thing.
            raise "#{new_resource.to_s} provided #{new_resource.class.aws_id_attribute} #{desired_id} in #{desired_driver.driver_url}, but is currently associated with #{entry_id} in #{entry_driver.driver_url}.  Cannot delete the entry or the association until this inconsistency is resolved."
          else
            Chef::Log.debug "#{new_resource.to_s} provided #{new_resource.class.aws_id_attribute} #{desired_id} in #{desired_driver.driver_url}, but is currently associated with #{entry_id} in #{entry_driver.driver_url}, which does not exist.  Will delete #{desired_id} and disassociate from #{entry_id}."
          end
        else

          # Normal case: entry exists, and is the same as desired (or no desired)
          aws_object = new_resource.class.get_aws_object(entry_id, driver: entry_driver, resource: new_resource, required: false)
          if aws_object
            Chef::Log.debug "#{new_resource.to_s} is associated with #{entry_id} in #{entry_driver.driver_url}.  Will delete."
          else
            Chef::Log.debug "#{new_resource.to_s} is associated with #{entry_id} in #{entry_driver.driver_url}, but it does not exist.  Will disassociate the entry but not delete."
          end
        end
      end

    #
    # Non-managed entries all have their own way of looking it up
    #
    else
      aws_object ||= new_resource.aws_object
    end

    #
    # Call the delete method
    #
    if aws_object
      destroy_aws_object(aws_object)
    end

    #
    # Associate the managed entry with the AWS object
    #
    if new_resource.is_a?(AWSResourceWithEntry) && entry
      new_resource.delete_managed_entry(action_handler)
    end
  end

  protected

  def create_aws_object
    raise NotImplementedError, :create_aws_object
  end

  def update_aws_object(obj)
    raise NotImplementedError, :update_aws_object
  end

  def destroy_aws_object(obj)
    raise NotImplementedError, :destroy_aws_object
  end

  # Update AWS resource tags
  #
  # AWS resources which include the TaggedItem Module
  # will have an 'aws_tags' attribute available.
  # The 'aws_tags' Hash will apply all the tags within
  # the hash, and remove existing tags not included within
  # the hash.  The 'Name' tag will not removed.  The 'Name'
  # tag can still be updated in the hash.
  #
  # @param aws_object Aws SDK Object to update tags
  #
  def converge_tags(aws_object)
    desired_tags = new_resource.aws_tags
    # If aws_tags were not provided we exit
    if desired_tags.nil?
      Chef::Log.debug "aws_tags not provided, nothing to converge"
      return
    end
    current_tags = aws_object.tags.to_h
    # AWS always returns tags as strings, and we don't want to overwrite a
    # tag-as-string with the same tag-as-symbol
    desired_tags = Hash[desired_tags.map {|k, v| [k.to_s, v.to_s] }]
    tags_to_delete = current_tags.keys - desired_tags.keys
    # We don't want to delete `Name`, just all other tags
    tags_to_delete.delete('Name')

    unless desired_tags.empty?
      converge_by "applying tags #{desired_tags}" do
        aws_object.tags.set(desired_tags)
      end
    end
    unless tags_to_delete.empty?
      converge_by "deleting tags #{tags_to_delete.inspect}" do
        aws_object.tags.delete(*tags_to_delete)
      end
    end
  end

  # Wait until aws_object obtains one of expected_status
  #
  # @param aws_object Aws SDK Object to check status on
  # @param expected_status [Symbol,Array<Symbol>] Final status(s) to look for
  # @param acceptable_errors [Exception,Array<Exception>] Acceptable errors that are caught and squelched
  # @param tries [Integer] Number of times to check status
  # @param sleep [Integer] Time to wait between checking status
  #
  def wait_for_status(aws_object, expected_status, acceptable_errors = [], tries=60, sleep=5)
    acceptable_errors = [acceptable_errors].flatten
    expected_status = [expected_status].flatten
    current_status = aws_object.status

    Retryable.retryable(:tries => tries, :sleep => sleep, :on => StatusTimeoutError) do |retries, exception|
      action_handler.report_progress "waited #{retries*sleep}/#{tries*sleep}s for #{aws_object.id} status to change to #{expected_status.inspect}..."
      begin
        current_status = aws_object.status
        unless expected_status.include?(current_status)
          raise StatusTimeoutError.new(aws_object, current_status, expected_status)
        end
      rescue *acceptable_errors
      end
    end
  end

end
end
