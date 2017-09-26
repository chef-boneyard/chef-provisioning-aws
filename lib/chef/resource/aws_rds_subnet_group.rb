require 'chef/provisioning/aws_driver/aws_rds_resource'
require 'chef/provisioning/aws_driver/aws_taggable'
require 'chef/resource/aws_subnet'

class Chef::Resource::AwsRdsSubnetGroup < Chef::Provisioning::AWSDriver::AWSRDSResource
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type ::Aws::RDS

  attribute :name, kind_of: String, name_attribute: true
  attribute :description, kind_of: String, required: true
  attribute :subnets,
            kind_of: [ String, Array, AwsSubnet, ::Aws::EC2::Subnet ],
            required: true,
            coerce: proc { |v| [v].flatten }

  def aws_object
    driver.rds.describe_db_subnet_groups(db_subnet_group_name: name)[:db_subnet_groups].first
  rescue ::Aws::RDS::Errors::DBSubnetGroupNotFoundFault
    # triggered by describe_db_subnet_groups when the group can't
    # be found
    nil
  end

  def rds_tagging_type
    "subgrp"
  end
end
