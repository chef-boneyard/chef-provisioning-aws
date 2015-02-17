require 'chef/provider/aws_provider'

class Chef::Provider::AwsRdsDbSubnetGroup < Chef::Provider::AwsProvider

  action :create do

    options = {
      :db_subnet_group_name => new_resource.name,
      :db_subnet_group_description => new_resource.description,
    }


    subnets_ids = ec2.subnets.with_tag('Name', new_resource.subnets).map { |s| s.id }

    options[:subnet_ids] = subnets_ids;
    converge_by "Creating new RDS subnet group" do
      dbInstance = rds.client.create_db_subnet_group(options)
    end

  end

end
