require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsRdsInstance < Chef::Provisioning::AWSDriver::AWSProvider
  REQUIRED_OPTIONS = %w(db_instance_identifier allocated_storage engine
                        db_instance_class master_username master_user_password)

  OTHER_OPTIONS = %w(engine_version multi_az iops publicly_accessible db_name db_port db_subnet_group_name)

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
    opts.merge(new_resource.additional_options)
    REQUIRED_OPTIONS.each do |opt|
      opts[opt] = new_resource.send(opt.to_sym)
    end
    OTHER_OPTIONS.each do |opt|
      opts[opt] = new_resource.send(opt.to_sym) if ! new_resource.send(opt.to_sym).nil?
    end
    opts[:tags] = hash_to_tag_array(new_resource.aws_tags) if new_resource.aws_tags
    opts
  end

  private

  # To be in line with the other resources. The aws_tags property
  # takes a hash.  But we actually need an array.
  def tag_hash_to_array(tag_hash)
    ret = []
    tag_hash.each do |key, value|
      ret << {:key => key, :value => value}
    end
    ret
  end
end
