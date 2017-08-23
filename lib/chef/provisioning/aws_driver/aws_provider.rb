require 'chef/provider/lwrp_base'
require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/provisioning/aws_driver/aws_resource_with_entry'
require 'chef/provisioning/chef_managed_entry_store'
require 'chef/provisioning/chef_provider_action_handler'
# Enough providers will require this that we put it in here
require 'chef/provisioning/aws_driver/tagging_strategy/ec2'
require 'retryable'

module Chef::Provisioning::AWSDriver
class AWSProvider < Chef::Provider::LWRPBase
  use_inline_resources

  AWSResource = Chef::Provisioning::AWSDriver::AWSResource

  class StatusTimeoutError < ::Timeout::Error
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
    new_resource.driver.aws_config[:region]
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

    #
    # Associate the managed entry with the AWS object
    #
    if new_resource.is_a?(AWSResourceWithEntry)
      new_resource.save_managed_entry(aws_object, action_handler, existing_entry: entry)
    end

    # This has to be after the managed entry save so the `aws_object` lookup
    # from the resource succeeds
    if respond_to?(:converge_tags)
      converge_tags
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

  def wait_for_status(aws_object, expected_status, acceptable_errors = [], tries=60, sleep=5)
    wait_for(
      aws_object: aws_object,
      query_method: :status,
      expected_responses: expected_status,
      acceptable_errors: acceptable_errors,
      tries: tries,
      sleep: sleep
    )
  end

  def wait_for_state(aws_object, expected_states, acceptable_errors = [], tries=60, sleep=5)
    wait_for(
      aws_object: aws_object,
      query_method: :state,
      expected_responses: expected_states,
      acceptable_errors: acceptable_errors,
      tries: tries,
      sleep: sleep
    )
  end

  # Wait until aws_object obtains one of expected_responses
  #
  # @param aws_object Aws SDK Object to check state on
  # @param query_method Method to call on aws_object to get current state
  # @param expected_responses [Symbol,Array<Symbol>] Final state(s) to look for
  # @param acceptable_errors [Exception,Array<Exception>] Acceptable errors that are caught and squelched
  # @param tries [Integer] Number of times to check state, defaults to 60
  # @param sleep [Integer] Time to wait between checking states, defaults to 5
  #
  def wait_for(opts={})
    aws_object = opts[:aws_object]
    query_method = opts[:query_method]
    expected_responses = [opts[:expected_responses]].flatten
    acceptable_errors = [opts[:acceptable_errors] || []].flatten
    tries = opts[:tries] || 60
    sleep = opts[:sleep] || 5

    Retryable.retryable(:tries => tries, :sleep => sleep) do |retries, exception|
      action_handler.report_progress "waited #{retries*sleep}/#{tries*sleep}s for <#{aws_object.class}:#{aws_object.id}>##{query_method} state to change to #{expected_responses.inspect}..."
      Chef::Log.debug("Current exception in wait_for is #{exception.inspect}") if exception
      begin
        yield(aws_object) if block_given?
        if aws_object.class.to_s.eql?("Aws::EC2::Vpc")
          vpc = new_resource.driver.ec2.describe_vpcs(vpc_ids: [aws_object.vpc_id]).vpcs
          current_response = "[:#{vpc[0].state}]"
        elsif aws_object.class.to_s.eql?("Aws::EC2::NetworkInterface")
          result = new_resource.driver.ec2_resource.network_interface(aws_object.id)
          current_response = "[:#{result.status}]"
          current_response = "[:in_use]" if current_response.eql?("[:in-use]")
        elsif aws_object.class.to_s.eql?("Aws::EC2::NatGateway")
          current_response = "[:#{aws_object.state}]"
        end
        Chef::Log.debug("Current response in wait_for from [#{query_method}] is #{current_response}")
        unless expected_responses.to_s.include?(current_response)
          raise StatusTimeoutError.new(aws_object, current_response, expected_responses)
        end
      rescue *acceptable_errors
      end
    end
  end

  # Retry a block with an doubling backoff time (maximum wait of 10 seconds).
  # @param retry_on [Exception] An exception to retry on, defaults to RuntimeError
  #
  def self.retry_with_backoff(*retry_on)
    retry_on ||= [RuntimeError]
    Retryable.retryable(:tries => 10, :sleep => lambda { |n| [2**n, 16].min }, :on => retry_on) do |retries, exception|
      Chef::Log.debug("Current exception in retry_with_backoff is #{exception.inspect}")
      yield
    end
  end

  def retry_with_backoff(*retry_on, &block)
    self.class.retry_with_backoff(*retry_on, &block)
  end

end
end
