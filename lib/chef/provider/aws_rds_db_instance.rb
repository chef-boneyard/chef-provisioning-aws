require 'chef/resource/aws_resource'
require 'chef/provider/aws_provider'

class Chef::Provider::AwsRdsDbInstance < Chef::Provider::AwsProvider

  action :create do

    options = {
      :allocated_storage => new_resource.allocated_storage,
      :db_instance_class => new_resource.db_instance_class,
      :engine => new_resource.engine,
      :master_username => new_resource.master_username,
      :master_user_password => new_resource.master_user_password,
      :db_subnet_group_name => new_resource.db_subnet_group_name
    }

    converge_by "Creating new RDS database with engine #{new_resource.engine}" do
      dbInstance = rds.db_instances.create(new_resource.name, options)
    end

  end

end
