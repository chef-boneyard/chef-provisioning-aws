require 'chef/resource/lwrp_base'
require 'chef/provisioning/chef_managed_entry_store'
require 'chef/provisioning/aws_driver/managed_aws'

# Common AWS resource - contains metadata that all AWS resources will need
class Chef::Resource::AWSResource < Chef::Provisioning::AWSDriver::SuperLWRP
  def initialize(*args)
    super
    driver run_context.chef_provisioning.current_driver
    chef_server run_context.cheffish.current_chef_server
  end

  #
  # The desired driver.
  #
  attribute :driver, kind_of: Chef::Provisioning::Driver,
                     coerce { |value| run_context.chef_provisioning.driver_for(value) }

  #
  # The Chef server on which any IDs should be looked up.
  #
  attribute :chef_server, kind_of: Hash

  #
  # The managed entry store.
  #
  attribute :managed_entries, kind_of: Chef::Provisioning::ManagedEntryStore,
                              default { Chef::Provisioning::ChefManagedEntryStore.new(chef_server) }

  def initialize(name, run_context=nil)
    # Let the class handle special names
    name = self.class.aws_object_id(name) if name.is_a?(self.class.aws_sdk_class)
    super
  end

  def build_arn(service, resource)
    "arn:aws:#{service}:#{driver.region}:#{driver.account_id}:#{resource}"
  end

  #
  # Get the current AWS object.
  #
  def aws_object
    raise NotImplementedError, :aws_object
  end

  def self.lookup_options(options, run_context: nil, driver: nil, managed_entries: nil)
    result = {}
    options.each do |name, value|
      if aws_option_handlers[name]
        options[name] = aws_option_handlers[name].lookup_option(value, run_context: run_context, driver: driver, managed_entries: managed_entries)
      end
      result[name]
    end
    result
  end

  protected

  def self.lookup_option(value, run_context: nil, driver: nil, managed_entries: nil)
    resource = new(value, run_context)
    resource.driver driver
    resource.managed_entries managed_entries
    o = aws_object
    aws_object_id(o) if o
  end

  def self.aws_object_id(aws_object)
    aws_object.public_send(aws_sdk_class_id)
  end

  def self.aws_sdk_type(sdk_class,
                        option_name: :"#{resource_name[4..-1]}",
                        id: :name)
    self.resource_name = self.dsl_name
    @aws_sdk_class = sdk_class
    @aws_sdk_class_id = id

    # Go ahead and require the provider since we're here anyway ...
    require "chef/provider/#{resource_name}"

    aws_option_handlers[option_name] = self if option_name
    aws_option_handlers[:"#{option_name}_#{aws_sdk_class_id}"] = self if option_name && aws_sdk_class_id
  end

  def self.aws_sdk_class
    @aws_sdk_class
  end

  def self.aws_sdk_class_id
    @aws_sdk_class_id
  end
end
