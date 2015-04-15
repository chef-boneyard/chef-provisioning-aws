require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsRdsDbInstance < Chef::Provisioning::AWSDriver::AWSProvider

  action :create do
    db_instance = new_resource.aws_object
    
    if db_instance == nil
      create_db_instance
    end
  end

  def create_db_instance
    db_instance = nil
    converge_by "Creating new RDS database with engine #{new_resource.engine}" do
      options = {
      }
      options = AWSResource.lookup_options(options, resource: new_resource)
      db_instance = driver.rds.db_instances.create(new_resource.db_instance_identifier, options)
      new_resource.save_managed_entry(db_instance, action_handler)
    end
    db_instance
  end

end
