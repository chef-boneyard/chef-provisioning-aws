require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/provisioning/aws_driver/tagging_strategy/ec2'

class Chef::Provider::AwsImage < Chef::Provisioning::AWSDriver::AWSProvider
  include Chef::Provisioning::AWSDriver::TaggingStrategy::EC2ConvergeTags

  provides :aws_image

  def destroy_aws_object(image)
    instance_id = image.tags.map {|t| [t.key, t.value] }.to_h['from-instance']
    Chef::Log.debug("Found from-instance tag [#{instance_id}] on #{image.id}")
    unless instance_id
      # This is an old image and doesn't have the tag added - lets try and find it from the block device mapping
      image.block_device_mappings.map do |dev, opts|
        snapshot = new_resource.driver.ec2_resource.snapshot(opts[:snapshot_id])
        desc = snapshot.description
        m = /CreateImage\(([^\)]+)\)/.match(desc)
        if m
          Chef::Log.debug("Found [#{instance_id}] from snapshot #{snapshot.id} on #{image.id}")
          instance_id = m[1]
        end
      end
    end
    converge_by "deregister image #{new_resource} in #{region}" do
      image.deregister
    end
    if instance_id
      # As part of the image creation process, the source instance was automatically
      # destroyed - we just need to make sure that has completed successfully
      instance = new_resource.driver.ec2_resource.instance(instance_id)
      converge_by "waiting until instance #{instance.id} is :terminated" do
        if instance.exists?
          instance.wait_until_terminated do |w|
            w.delay = 5
            w.max_attempts = 60
            w.before_wait do |attempts, response|
              action_handler.report_progress "waited #{(attempts-1)*5}/#{60*5}s for #{instance.id} status to terminate..."
            end
          end
        end
      end
    end
  end
end
