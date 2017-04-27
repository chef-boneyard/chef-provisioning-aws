require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/provisioning/aws_driver/resources'

# Common AWS resource - contains metadata that all AWS resources will need
class Chef::Provisioning::AWSDriver::AWSResourceWithEntry < Chef::Provisioning::AWSDriver::AWSResource

  #
  # Dissociate the ID of this object from Chef.
  #
  # @param action_handler [Chef::Provisioning::ActionHandler] The action handler,
  #        which handles progress reporting, update reporting ("little green text")
  #        and dry run.
  #
  def delete_managed_entry(action_handler)
    if should_have_managed_entry?
      managed_entry_store.delete(self.class.managed_entry_type, name, action_handler)
    end
  end

  #
  # Save the ID of this object to Chef.
  #
  # @param aws_object [::Aws::EC2::Core] The AWS object containing the ID.
  # @param action_handler [Chef::Provisioning::ActionHandler] The action handler,
  #        which handles progress reporting, update reporting ("little green text")
  #        and dry run.
  # @param existing_entry [Chef::Provisioning::ManagedEntry] The existing entry
  #        (if any).  If this is passed in, and no values are changed, we will
  #        not attempt to update it (this prevents us from retrieving it twice).
  #
  def save_managed_entry(aws_object, action_handler, existing_entry: nil)
    if should_have_managed_entry?
      managed_entry = existing_entry ||
                      managed_entry_store.new_entry(self.class.managed_entry_type, name)
      updated = update_managed_entry(aws_object, managed_entry)
      if updated || !existing_entry
        managed_entry.save(action_handler)
      end
    end
  end

  def get_id_from_managed_entry
    if should_have_managed_entry?
      entry = managed_entry_store.get(self.class.managed_entry_type, name)
      if entry
        driver = self.driver
        if entry.driver_url != driver.driver_url
          # TODO some people don't send us run_context (like Drivers).  We might need
          # to exit early here if the driver_url doesn't match the provided driver.
          driver = run_context.chef_provisioning.driver_for(entry.driver_url)
        end
        [ driver, entry.reference[self.class.managed_entry_id_name], entry ]
      end
    end
  end

  # Formatted output for logging statements - contains resource type, resource name and aws object id (if available)
  def to_s
    id = get_driver_and_id[1]
    "#{declared_type}[#{@name}] (#{ id ? id : 'no AWS object id'})"
  end

  protected

  #
  # Update an existing ManagedEntry object.
  #
  # @return true if the entry was changed, and false if not
  #
  def update_managed_entry(aws_object, managed_entry)
    new_value = { self.class.managed_entry_id_name => aws_object.public_send(self.class.aws_sdk_class_id) }
    if managed_entry.reference != new_value
      managed_entry.reference = new_value
      changed = true
    end
    if managed_entry.driver_url != driver.driver_url
      managed_entry.driver_url = driver.driver_url
      changed = true
    end
    changed
  end

  def get_driver_and_id
    driver, id, entry = get_id_from_managed_entry
    # If the value isn't already stored, look up the user-specified public_ip
    driver, id = self.driver, self.public_send(self.class.aws_id_attribute) if !id
    [ driver, id ]
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

  def should_have_managed_entry?
    name != public_send(self.class.aws_id_attribute)
  end
end
