require 'chef/provider/aws_provider'

class Chef::Provider::AwsRdsDbSubnetGroup < Chef::Provider::AwsProvider

  action :create do

    if existing_db_subnet_group == nil

      subnet_ids = ec2.subnets.with_tag('Name', new_resource.subnets).map { |s| s.id }

      options = {
        :db_subnet_group_name => new_resource.name,
        :db_subnet_group_description => new_resource.description,
        :subnet_ids => subnet_ids
      }
 
      converge_by "Creating new RDS subnet group" do
        dbInstance = rds.client.create_db_subnet_group(options)
      end

    end
  end

  def existing_db_subnet_group
    @existing_db_subnet_group ||= begin
      rds.client.describe_db_subnet_groups(db_subnet_group_name: new_resource.name).first
    rescue
      nil
    end
  end

end
