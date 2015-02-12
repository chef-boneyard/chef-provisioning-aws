require 'chef/provider/aws_provider'
require 'cheffish'
require 'date'
require 'retryable'

class Chef::Provider::AwsEc2Volume < Chef::Provider::AwsProvider

  use_inline_resources

  action :create do
    if existing_volume.nil?
      # todo fix all region_name vars, => nil
      converge_by "Creating new EBS volume #{fqn} in #{new_resource.region_name}" do

        @existing_volume = ec2.volumes.create(
            :availability_zone => new_resource.availability_zone,
            :size => new_resource.size,
            :snapshot_id => new_resource.snapshot_id,
            :volume_type => new_resource.volume_type.to_s,
            :iops => new_resource.iops,
            :encrypted => new_resource.encrypted
        )

        existing_volume.tags['Name'] = fqn

        wait_for_volume_status(:available)

        new_resource.created_at DateTime.now.to_s
        new_resource.volume_id existing_volume.id
      end
    else
      new_resource.volume_id existing_volume.id
    end

    new_resource.save
  end

  action :delete do
    if existing_volume
      begin
        converge_by "Deleting EBS volume #{fqn} in #{new_resource.region_name}" do
          existing_volume.delete

          Retryable.retryable(:tries => 30, :sleep => 2, :on => TimeoutError) do
            raise TimeoutError,
              "Timed out waiting for volume #{new_resource.volume_id} to be deleted." if existing_volume.exists?
          end
        end
      end
    end

    new_resource.delete
  end

  action :attach do
    if existing_volume
      begin
        converge_by "Attaching EBS volume #{fqn} in #{new_resource.region_name} to instance #{new_resource.instance_id}" do

          existing_volume.attach_to(
            ec2.instances[new_resource.instance_id],
            new_resource.device
          )
          new_resource.attached_to_instance new_resource.instance_id
          new_resource.attached_to_device new_resource.device

          wait_for_volume_status(:in_use)
        end
      rescue AWS::EC2::Errors::VolumeInUse => e
        # assume attached correctly, still need to check if its the intended instance
        Chef::Log.debug(e.message)
        new_resource.updated_by_last_action(true)
      end
    end

    new_resource.save
  end

  action :detach do
    if existing_volume
      begin
        converge_by "Detaching EBS volume #{fqn} in #{new_resource.region_name} from instance #{new_resource.instance_id}" do
          existing_volume.detach_from(
              ec2.instances[new_resource.attached_to_instance],
              new_resource.attached_to_device,
              :force => true
            )
            # todo load current resource and remove keys
            new_resource.attached_to_instance ''
            new_resource.attached_to_device ''

            wait_for_volume_status(:available)
        end
      rescue AWS::EC2::Errors::IncorrectState => e
        # assume detached correctly
        Chef::Log.debug(e.message)
        new_resource.updated_by_last_action(true)
      end
    end

    new_resource.save
  end

  def existing_volume
    @existing_volume ||=  new_resource.volume_id == nil ? nil : begin
      Chef::Log.debug("Loading volume #{new_resource.volume_id}")
      volume = ec2.volumes[new_resource.volume_id]
      if [:deleted, :deleting, :error].include? volume.status
        nil
      else
        Chef::Log.debug("Found EBS volume #{volume.inspect}")
        volume
      end
    rescue => e
      Chef::Log.error("Error looking for EBS volume: #{e}")
      nil
    end
  end

  def id
    new_resource.name
  end

  private

  def wait_for_volume_status(status)
    ensure_cb = Proc.new do
      Chef::Log.debug("Waiting for volume status: #{status.to_s}")
    end

    Retryable.retryable(:tries => 30, :sleep => 2, :on => TimeoutError, :ensure => ensure_cb) do
      raise TimeoutError, "Timed out waiting for volume status: #{status.to_s}" unless existing_volume.status == status
    end
  end

end
