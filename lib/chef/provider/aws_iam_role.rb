require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsIamRole < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_iam_role

  protected

  def create_aws_object
    iam = new_resource.driver.iam_resource

    converge_by "create IAM role #{new_resource.name}" do
      iam.create_role({
        path: new_resource.path,
        role_name: new_resource.name,
        assume_role_policy_document: new_resource.assume_role_policy_document
      })
    end
  end

  def update_aws_object(iam_role)
  end

  def destroy_aws_object(iam_role)
    converge_by "delete IAM role #{iam_role.name}" do
      iam_role.instance_profiles.each do |profile|
        profile.remove_role(role_name: iam_role.name)
      end
      iam_role.policies.each do |policy|
        Cheffish.inline_resource(self, action) do
          aws_iam_role_policy policy.name do
            role iam_role.name
            action :destroy
          end
        end
      end
      iam_role.delete
    end
  end

end
