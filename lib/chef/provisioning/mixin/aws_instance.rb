module Chef::Provisioning::Mixin::AWSInstance
  def self.instance
    Chef::Resource::AwsInstance.get_aws_object(new_resource.machine, resource: new_resource)
  end
end
