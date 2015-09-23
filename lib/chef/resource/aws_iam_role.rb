require 'chef/provisioning/aws_driver/aws_resource'

#
# An AWS IAM role, specifying set of policies for acessing other AWS services.
#
# `name` is unique for an AWS account.
#
# API documentation for the AWS Ruby SDK for IAM roles (and the object returned from `aws_object`) can be found here:
#
# - http://docs.aws.amazon.com/sdkforruby/api/Aws/IAM.html
#
class Chef::Resource::AwsIamRole < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type ::Aws::IAM::Role, id: :name

  #
  # The name of the role to create.
  #
  attribute :name,   kind_of: String, name_attribute: true

  #
  # The path to the role. For more information about paths, see http://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html
  #
  attribute :path,    kind_of: [ String ]

  #
  # The policy that grants an entity permission to assume the role.
  #
  attribute :assume_role_policy_document, kind_of: [ String, Array ], required: true

  def aws_object
    driver.iam_resource.role(name).load
  rescue ::Aws::IAM::Errors::NoSuchEntity
    nil
  end

end
