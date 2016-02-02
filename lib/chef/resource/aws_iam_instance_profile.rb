require 'chef/provisioning/aws_driver/aws_resource'

#
# An AWS IAM instance profile, a container for an IAM role that you can use to
# pass role information to an EC2 instance when the instance starts..
#
# `name` is unique for an AWS account.
#
# API documentation for the AWS Ruby SDK for IAM instance profiles (and the object returned from `aws_object`) can be found here:
#
# - http://docs.aws.amazon.com/sdkforruby/api/Aws/IAM/InstanceProfile.html
#
class Chef::Resource::AwsIamInstanceProfile < Chef::Provisioning::AWSDriver::AWSResource
  # We don't want any lookup_options to try and build a resource from a :iam_instance_profile string,
  # its either a name or an ARN
  aws_sdk_type ::Aws::IAM::InstanceProfile, :option_names => []

  #
  # The name of the instance profile to create.
  #
  attribute :name,   kind_of: String, name_attribute: true

  #
  # The path to the instance profile. For more information about paths, see http://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html
  #
  attribute :path,    kind_of: String

  attribute :role,    kind_of: [ String, AwsIamRole, ::Aws::IAM::Role]

  def aws_object
    result = driver.iam_resource.instance_profile(name)
    result && result.exists? ? result : nil
  end

end
