require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsInstanceProfile < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_iam_instance_profile

  def action_create
    iam_instance_profile = super

    if new_resource.role && !iam_instance_profile.roles.map(&:name).include?(new_resource.role)
      converge_by "associating role #{new_resource.role} with instance profile #{new_resource.name}" do
        # Despite having collection methods for roles, instance profile can only have single role associated
        detach_role(iam_instance_profile)
        iam_instance_profile.add_role({
          role_name: new_resource.role
        })
      end
    end
  end

  protected

  def detach_role(iam_instance_profile)
    iam_instance_profile.roles.each do |r|
      iam_instance_profile.remove_role(role_name: r.name)
    end
  end

  def create_aws_object
    iam = new_resource.driver.iam_resource

    converge_by "create IAM instance profile #{new_resource.name}" do
      iam.create_instance_profile({
        path: new_resource.path || "/",
        instance_profile_name: new_resource.name
      })
    end
  end

  def update_aws_object(iam_instance_profile)
  end

  def destroy_aws_object(iam_instance_profile)
    converge_by "delete #{iam_instance_profile.name}" do
      detach_role(iam_instance_profile)
      iam_instance_profile.delete
    end
  end

end
