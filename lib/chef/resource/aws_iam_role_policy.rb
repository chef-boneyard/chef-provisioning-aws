require 'chef/provisioning/aws_driver/aws_resource'

#
# An AWS IAM role policy, describing rules for acessing other AWS services.
#
# `name` is unique for an AWS account.
#
# API documentation for the AWS Ruby SDK for IAM role policies (and the object returned from `aws_object`) can be found here:
#
# - http://docs.aws.amazon.com/sdkforruby/api/Aws/IAM/RolePolicy.html
#
class Chef::Resource::AwsIamRolePolicy < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type ::Aws::IAM::RolePolicy

  #
  # The name of the policy to create
  #
  attribute :name, kind_of: String, name_attribute: true

  #
  # The name of the role policy belongs to
  #
  attribute :role, kind_of: [ String, AwsIamRole, ::Aws::IAM::Role], required: true

  #
  # JSON that actually describes permissions to AWS services
  #
  attribute :policy_document, kind_of: String, required: true

  def aws_object
    options = Chef::Provisioning::AWSDriver::AWSResource.lookup_options({ role: role }, resource: self)
    driver.iam_resource.role(options[:role]).policy(name).load
  rescue ::Aws::IAM::Errors::NoSuchEntity
    nil
  end

end
