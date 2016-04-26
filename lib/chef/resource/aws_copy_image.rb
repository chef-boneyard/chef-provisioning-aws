require 'chef/provisioning/aws_driver/aws_resource'

#
# This provider goal is enable the copy of a machine image from the current driver region to another one.
#
# `name` is the name or id of AMI to copy.
# `target_region` is the destination region for the AMI.
# `target_name` is the name of the AMI after being copied. Default it's the source image name.
#
class Chef::Resource::AwsCopyImage < Chef::Provisioning::AWSDriver::AWSResource
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type Aws::EC2::Image
  actions :copy
  default_action :copy

  attribute :name, kind_of: String, name_attribute: true
  attribute :destination_region, kind_of: String, required: true

  attribute :target_name, kind_of: String
  attribute :target_description, kind_of: String
end

