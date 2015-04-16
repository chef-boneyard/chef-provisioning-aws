require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsImage < Chef::Provisioning::AWSDriver::AWSProvider
  def destroy_aws_object(image)
    instance_id = image.tags['From-Instance']
    Chef::Log.debug("Found From-Instance tag [#{instance_id}] on #{image.id}")
    unless instance_id
      # This is an old image and doesn't have the tag added - lets try and find it from the block device mapping
      image.block_device_mappings.map do |dev, opts|
        snapshot = ec2.snapshots[opts[:snapshot_id]]
        desc = snapshot.description
        m = /CreateImage\(([^\)]+)\)/.match(desc)
        if m
          Chef::Log.debug("Found [#{instance_id}] from snapshot #{snapshot.id} on #{image.id}")
          instance_id = m[1]
        end
      end
    end
    converge_by "delete image #{new_resource} in #{region}" do
      image.delete
    end
    if instance_id
      # As part of the image creation process, the source instance was automatically
      # destroyed - we just need to make sure that has completed successfully
      instance = new_resource.driver.ec2.instances[instance_id]
      converge_by "waiting until instance #{instance.id} is :terminated" do
        wait_for_status(instance, :terminated, [AWS::EC2::Errors::InvalidInstanceID::NotFound])
      end
    end
  end
end
