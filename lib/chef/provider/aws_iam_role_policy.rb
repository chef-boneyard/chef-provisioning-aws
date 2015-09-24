require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsIamRolePolicy < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_iam_role_policy

  protected

  def create_aws_object
    iam = new_resource.driver.iam_client

    converge_by "create IAM role policy #{new_resource.name}" do
      iam.put_role_policy({
        role_name: new_resource.role,
        policy_name: new_resource.name,
        policy_document: new_resource.policy_document
      })
    end
  end

  def update_aws_object(iam_role_policy)
    if update_required?(iam_role_policy)
      converge_by "update IAM role policy #{iam_role_policy.name}" do
        iam_role_policy.put({
          policy_document: new_resource.policy_document,
        })
      end
    end
  end

  def destroy_aws_object(iam_role_policy)
    converge_by "delete IAM role policy #{iam_role_policy.name}" do
      iam_role_policy.delete
    end
  end

  def update_required?(iam_role_policy)
    URI.decode(iam_role_policy.policy_document) != new_resource.policy_document
  end

end
