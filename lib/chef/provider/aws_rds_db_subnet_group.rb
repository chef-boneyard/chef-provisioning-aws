require 'chef/resource/aws_resource'
require 'chef/provider/aws_provider'

class Chef::Provider::AwsRdsDbSubnetGroup < Chef::Provider::AwsProvider

  action :create do

    fail "Can't create a subnet group without a description" if new_resource.description.nil?

    if existing_db_subnet_group == nil

      subnet_ids = new_driver.ec2.subnets.with_tag('Name', new_resource.subnets).map { |s| s.id }

      options = {
        :db_subnet_group_name => new_resource.name,
        :db_subnet_group_description => new_resource.description,
        :subnet_ids => subnet_ids
      }
 
      converge_by "Creating new RDS subnet group" do
        dbInstance = new_driver.rds.client.create_db_subnet_group(options)
        new_resource.save
      end

    end
  end

  action :delete do
    if existing_db_subnet_group
      converge_by "Deleting RDS subnet group #{new_resource.fqn} in #{new_driver.aws_config.region}" do      
        rds.client.delete_db_subnet_group(db_subnet_group_name: new_resource.name)
      end
    end

    new_resource.delete
  end

  def existing_db_subnet_group
    @existing_db_subnet_group ||= begin
      response = new_driver.rds.client.describe_db_subnet_groups(db_subnet_group_name: new_resource.name)
      response[:data][:db_subnet_groups].first
    rescue
      nil
    end
  end

end
