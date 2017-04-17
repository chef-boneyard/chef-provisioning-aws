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
  aws_sdk_type ::Aws::IAM::Role

  #
  # The name of the role to create.
  #
  attribute :name,   kind_of: String, name_attribute: true

  #
  # The path to the role. For more information about paths, see http://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html
  #
  attribute :path,   kind_of: String

  #
  # The policy that grants an entity permission to assume the role.
  #
  attribute :assume_role_policy_document, kind_of: String

  #
  # Inline policies which _only_ apply to this role, unlike managed_policies
  # which can be shared between users, groups and roles.  Maps to the
  # [RolePolicy](http://docs.aws.amazon.com/sdkforruby/api/Aws/IAM/RolePolicy.html)
  # SDK object.
  #
  # Hash keys are the inline policy name and the value is the policy document.
  #
  attribute :inline_policies, kind_of: Hash, callbacks: {
    "inline_policies must be a hash maping policy names to policy documents" => proc do |policies|
      policies.all? {|policy_name, policy| (policy_name.is_a?(String) || policy_name.is_a?(Symbol)) && policy.is_a?(String)}
    end
  }

  #
  # TODO: add when we get a policy resource
  #
  # attribute :managed_policies, kind_of: [Array, String, ::Aws::IAM::Policy, AwsIamPolicy], coerce: proc { |value| [value].flatten }

  def aws_object
    driver.iam_resource.role(name).load
  rescue ::Aws::IAM::Errors::NoSuchEntity
    nil
  end

end
