require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/json_compat'

class Chef::Provider::AwsIamRole < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_iam_role

  def iam_client
    new_resource.driver.iam_client
  end

  def iam_resource
    new_resource.driver.iam_resource
  end

  def action_create
    role = super

    if !new_resource.inline_policies.nil?
      update_inline_policy(role)
    end
  end

  protected

  def create_aws_object
    converge_by "create IAM Role #{new_resource.name}" do
      iam_resource.create_role({
        path: new_resource.path,
        role_name: new_resource.name,
        assume_role_policy_document: new_resource.assume_role_policy_document
      })
    end
    iam_resource.role(new_resource.name)
  end

  def update_aws_object(role)
    if new_resource.path && new_resource.path != role.path
      raise "Path of IAM Role #{new_resource.name} is #{role.path}, but desired path is #{new_resource.path}.  IAM Role paths cannot be updated!"
    end
    if new_resource.assume_role_policy_document && policy_update_required?(role.assume_role_policy_document, new_resource.assume_role_policy_document)
      converge_by "update IAM Role #{role.name} assume_role_policy_document" do
        iam_client.update_assume_role_policy({
          role_name: new_resource.name,
          policy_document: new_resource.assume_role_policy_document
        })
      end
    end
  end

  def destroy_aws_object(role)
    converge_by "delete IAM Role #{role.name}" do
      role.instance_profiles.each do |profile|
        profile.remove_role(role_name: role.name)
      end
      role.policies.each do |policy|
        converge_by "delete IAM Role inline policy #{policy.name}" do
          policy.delete
        end
      end
      role.delete
    end
  end

  private

  def update_inline_policy(role)
    desired_inline_policies = Hash[new_resource.inline_policies.map {|k, v| [k.to_s, v]}]
    current_inline_policies = Hash[role.policies.map {|p| [p.name, p.policy_document]}]

    policies_to_put = desired_inline_policies.reject {|k,v| current_inline_policies[k] && !policy_update_required?(current_inline_policies[k], v)}
    policies_to_delete = current_inline_policies.keys - desired_inline_policies.keys

    policies_to_put.each do |policy_name, policy|
      converge_by "Adding or updating inline Role policy #{policy_name}" do
        iam_client.put_role_policy({
          role_name: role.name,
          policy_name: policy_name,
          policy_document: policy
        })
      end
    end

    policies_to_delete.each do |policy_name|
      converge_by "Deleting inline Role policy #{policy_name}" do
        iam_client.delete_role_policy({
          role_name: role.name,
          policy_name: policy_name
        })
      end
    end
  end

  def policy_update_required?(current_policy, desired_policy)
    # We parse the JSON into a hash to get rid of whitespace and ordering issues
    Chef::JSONCompat.parse(URI.decode(current_policy)) != Chef::JSONCompat.parse(desired_policy)
  end

end
