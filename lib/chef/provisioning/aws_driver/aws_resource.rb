require 'aws'
require 'chef/provisioning/aws_driver/super_lwrp'
require 'chef/provisioning/chef_managed_entry_store'

# Common AWS resource - contains metadata that all AWS resources will need
module Chef::Provisioning::AWSDriver
class AWSResource < Chef::Provisioning::AWSDriver::SuperLWRP
  actions :create, :destroy, :purge, :nothing
  default_action :create

  def initialize(name, run_context=nil)
    name = name.public_send(self.class.aws_sdk_class_id) if name.is_a?(self.class.aws_sdk_class)
    super
    if run_context
      driver run_context.chef_provisioning.current_driver
      chef_server run_context.cheffish.current_chef_server
    end
  end

  # Backwards compatibility for action :destroy
  def action(*args)
    if args == [ :delete ]
      super(:destroy)
    else
      super
    end
  end
  def action=(value)
    action(value)
  end

  #
  # The desired driver.
  #
  attribute :driver, kind_of: Chef::Provisioning::Driver,
                     coerce: (proc do |value|
                               case value
                               when nil, Chef::Provisioning::Driver
                                 value
                               else
                                 run_context.chef_provisioning.driver_for(value)
                               end
                             end)

  #
  # The Chef server on which any IDs should be looked up.
  #
  attribute :chef_server, kind_of: Hash

  #
  # The managed entry store.
  #
  attribute :managed_entry_store, kind_of: Chef::Provisioning::ManagedEntryStore,
                              lazy_default: proc { Chef::Provisioning::ChefManagedEntryStore.new(chef_server) }

  #
  # Get the current AWS object.
  #
  def aws_object
    raise NotImplementedError, :aws_object
  end

  #
  # Look up an AWS options list, translating standard names using the appropriate
  # classes.
  #
  # For example, `load_balancer_options` is passed into `lookup_options`, and if
  # it looks like this: `{ subnets: `[ 'subnet1', 'subnet2' ] }`, then
  # `AWSResource.lookup_options` will translate each ID with
  # `AwsSubnet.get_aws_object('subnet1')`, which supports Chef names
  # (`mysubnet`) as well as AWS subnet Ids (`subnet-1234abcd`) or AWS objects
  # (`AWS::EC2::Subnet`).
  #
  # Keys that represent non-AWS-objects (such as `timeout`) are left alone.
  #
  def self.lookup_options(options, **handler_options)
    options = options.dup
    options.each do |name, value|
      if name.to_s.end_with?('s')
        handler_name = :"#{name[0..-2]}"
        if aws_option_handlers[handler_name]
          options[name] = [options[name]].flatten.map { |value| aws_option_handlers[handler_name].get_aws_object_id(value, **handler_options) }
        end
      else
        if aws_option_handlers[name]
          options[name] = aws_option_handlers[name].get_aws_object_id(value, **handler_options)
        end
      end
    end
    options
  end

  def self.get_aws_object(value, resource: nil, run_context: nil, driver: nil, managed_entry_store: nil, required: true)
    return nil if value.nil?

    if resource
      run_context         ||= resource.run_context
      driver              ||= resource.driver
      managed_entry_store ||= resource.managed_entry_store
    end
    if value.is_a?(self)
      resource = value
    else
      resource = new(value, run_context)
      resource.driver driver if driver
      resource.managed_entry_store managed_entry_store if managed_entry_store
    end
    result = resource.aws_object
    if required && result.nil?
      raise "#{self}[#{value}] does not exist!"
    end
    result
  end

  def self.get_aws_object_id(value, **options)
    aws_object = get_aws_object(value, **options)
    aws_object.public_send(aws_sdk_class_id) if aws_object
  end

  protected

  NOT_PASSED = Object.new

  def self.aws_sdk_type(sdk_class,
                        option_names: nil,
                        option_name: NOT_PASSED,
                        load_provider: true,
                        id: :name,
                        aws_id_prefix: nil)
    self.resource_name = self.dsl_name
    @aws_sdk_class = sdk_class
    @aws_sdk_class_id = id
    @aws_id_prefix = aws_id_prefix

    # Go ahead and require the provider since we're here anyway ...
    require "chef/provider/#{resource_name}" if load_provider

    option_name = :"#{resource_name[4..-1]}" if option_name == NOT_PASSED
    @aws_sdk_option_name = option_name

    option_names ||= begin
      option_names = []
      option_names << aws_sdk_option_name
      option_names << :"#{option_name}_#{aws_sdk_class_id}" if aws_sdk_class_id
      option_names
    end
    option_names.each do |option_name|
      aws_option_handlers[option_name] = self
    end

    name = self.name.split('::')[-1]
    eval("Chef::Provisioning::AWSDriver::Resources::#{name} = self", binding, __FILE__, __LINE__)
  end

  def self.aws_sdk_class
    @aws_sdk_class
  end

  def self.aws_sdk_class_id
    @aws_sdk_class_id
  end

  def self.aws_id_prefix
    @aws_id_prefix
  end

  def self.aws_sdk_option_name
    @aws_sdk_option_name
  end

  @@aws_option_handlers = {}
  def self.aws_option_handlers
    @@aws_option_handlers
  end

  # Add support for aws_id_attribute: true
  def self.attribute(name, aws_id_attribute: false, **validation_opts)
    @aws_id_attribute = name if aws_id_attribute
    super(name, validation_opts)
  end

  def self.aws_id_attribute
    @aws_id_attribute
  end
end
end
