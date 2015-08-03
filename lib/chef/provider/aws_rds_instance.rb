require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsRdsInstance < Chef::Provisioning::AWSDriver::AWSProvider
  REQUIRED_OPTIONS = %w(db_instance_identifier allocated_storage engine
                        db_instance_class master_username master_user_password)

  OTHER_OPTIONS = %w(engine_version multi_az iops publicly_accessible db_name db_port)

  def update_aws_object(instance)
    Chef::Log.warn("aws_rds_instance does not support modifying a started instance")
  end

  def create_aws_object
    converge_by "Create new RDS instance #{new_resource.db_instance_identifier} in #{region}" do
      new_resource.driver.rds.client.create_db_instance(create_options)
    end
  end

  def destroy_aws_object(instance)
    converge_by "Deleting RDS instance #{new_resource.db_instance_identifier} in #{region}" do
      instance.delete(skip_final_snapshot: true)
    end
  end

  def create_options
    opts = {}
    REQUIRED_OPTIONS.each do |opt|
      opts[opt] = new_resource.send(opt.to_sym)
    end
    OTHER_OPTIONS.each do |opt|
      opts[opt] = new_resource.send(opt.to_sym) if ! new_resource.send(opt.to_sym).nil?
    end
    opts.merge(new_resource.additional_options)
  end
end
