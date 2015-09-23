require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsIamRolePolicy < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_iam_role_policy

  def action_create
    iam_role_policy = super
  end

  protected

  def create_aws_object
    iam = new_resource.driver.iam_client

    converge_by "create IAM role policy #{new_resource.name}" do
      puts iam.put_role_policy({
        role_name: new_resource.role,
        policy_name: new_resource.name,
        policy_document: new_resource.policy_document
      }).inspect
    end
  end

  def update_aws_object(iam_role_policy)
  end

  def destroy_aws_object(iam_role_policy)
    converge_by "delete #{iam_role_policy.name}" do
      driver.iam_client.delete_role_policy({
        role_name: iam_role_policy.role,
        policy_name: iam_role_policy.name,
      })
    end
  end

end
