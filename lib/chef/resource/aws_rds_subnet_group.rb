require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/resource/aws_subnet'

class Chef::Resource::AwsRdsSubnetGroup < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type AWS::RDS

  attribute :db_subnet_group_name, kind_of: String, name_attribute: true
  attribute :db_subnet_group_description, kind_of: String
  attribute :subnet_ids, kind_of: Array
  attribute :aws_tags, kind_of: Hash

  def aws_object
    driver.rds.client
      .describe_db_subnet_groups(db_subnet_group_name: name)[:db_subnet_groups].first
  rescue AWS::RDS::Errors::DBSubnetGroupNotFoundFault
    # triggered by describe_db_subnet_groups when the group can't
    # be found
    nil
  end
end
