require 'chef/provisioning/aws_driver/aws_resource'

# Common AWS resource - contains metadata that all AWS resources will need
class Chef::Provisioning::AWSDriver::AWSResourceWithEntry < Chef::Provisioning::AWSDriver::AWSResource
  def delete_managed_entry(action_handler)
    managed_entry_store.delete(self.class.resource_name, name, action_handler)
  end

  def save_managed_entry(aws_object, action_handler)
    managed_entry = managed_entry_store.new_entry(self.class.resource_name, name)
    managed_entry.reference = { self.class.managed_entry_id_name => aws_object.public_send(self.class.aws_sdk_class_id) }
    managed_entry.driver_url = driver.driver_url
    managed_entry.save(action_handler)
  end

  protected

  def get_driver_and_id
    driver, id = get_id_from_managed_entry
    # If the value isn't already stored, look up the user-specified public_ip
    driver, id = self.driver, self.public_send(self.class.aws_id_attribute) if !id
    [ driver, id ]
  end

  # Add support for aws_id_attribute: true
  def self.attribute(name, validation_opts={})
    @aws_id_attribute = name if validation_opts.delete(:aws_id_attribute)
    super
  end

  def self.aws_id_attribute
    @aws_id_attribute
  end

  def self.aws_sdk_type(sdk_class,
                        id: :id,
                        managed_entry_type: nil,
                        managed_entry_id_name: 'id',
                        backcompat_data_bag_name: nil,
                        **options)
    super(sdk_class, id: id, **options)
    @managed_entry_type = managed_entry_type || resource_name.to_sym
    @managed_entry_id_name = managed_entry_id_name
    if backcompat_data_bag_name
      Chef::Provisioning::ChefManagedEntryStore.type_names_for_backcompat[resource_name] = backcompat_data_bag_name
    end
  end

  def self.managed_entry_type
    @managed_entry_type
  end

  def self.managed_entry_id_name
    @managed_entry_id_name
  end

  def get_id_from_managed_entry
    entry = managed_entry_store.get(self.class.managed_entry_type, name)
    if entry
      driver = self.driver
      if entry.driver_url != driver.driver_url
        # TODO some people don't send us run_context (like Drivers).  We might need
        # to exit early here if the driver_url doesn't match the provided driver.
        driver = run_context.chef_provisioning.driver_for(entry.driver_url)
      end
      [ driver, entry.reference[self.class.managed_entry_id_name] ]
    end
  end
end
