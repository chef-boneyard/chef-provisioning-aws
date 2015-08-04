require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/resource/aws_subnet'

class Chef::Resource::AwsRdsSubnetGroup < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type AWS::RDS

  attribute :name, kind_of: String, name_attribute: true
  attribute :description, kind_of: String, required: true
  attribute :subnets,
            kind_of: [ String, Array, AwsSubnet, AWS::EC2::Subnet ],
            required: true,
            coerce: proc { |v| [v].flatten }
  # aws_tags are going to fail for now because there isn't an AWS objects
  # we can call `.tags` on
  #attribute :aws_tags, kind_of: Hash

  def aws_object
    driver.rds.client
      .describe_db_subnet_groups(db_subnet_group_name: name)[:db_subnet_groups].first
  rescue AWS::RDS::Errors::DBSubnetGroupNotFoundFault
    # triggered by describe_db_subnet_groups when the group can't
    # be found
    nil
  end
end
