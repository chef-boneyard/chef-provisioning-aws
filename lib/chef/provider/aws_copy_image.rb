require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/provisioning/aws_driver/aws_resource'
require 'chef/provisioning/chef_managed_entry_store'

class Chef::Provider::AwsCopyImage < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_copy_image

  def action_copy
    @drivers = {}
    @source_driver = new_resource.driver
    _, @profile_name, @source_region = @source_driver.driver_url.split(':')

    # Get image to copy from the actual region (given from the driver)
    @source_image = Chef::Resource::AwsImage.get_aws_object(new_resource.name,resource: new_resource)
    @target_name = new_resource.target_name || @source_image.name

    copy_image(new_resource.destination_region)
  end

  protected

  def copy_image(target_region)
    converge_by "Copy ami '#{@source_image.name}' from '#{@source_region}' to '#{target_region}'. "\
    "Target name: #{@target_name}" do
      # Get image in the target region
      target_image = fetch_image_for_region(target_region)

      # Copy image if image don't exist on the target region, and get the image object
      target_image = copy_image_to_region(target_region) unless target_image and target_image.exists?

      tag_the_image(target_region, target_image)

      # Wait for the image be ready
      ready_image(target_region, target_image)

      target_image
    end
  end

  def driver_for_region(target_region)
    @drivers[target_region] ||= Chef::Provisioning::AWSDriver::Driver.new("aws:#{@profile_name}:#{target_region}",
                                                                          @source_driver.config)
  end

  def tag_the_image(target_region, target_image)
    aws_tags = {}
    aws_tags['from-image'] = @source_image.image_id
    aws_tags['from-image-region'] =  @source_region
    aws_tags = aws_tags.merge(new_resource.aws_tags) unless new_resource.aws_tags.nil?

    driver_for_region(target_region).converge_ec2_tags(target_image, aws_tags, action_handler)
  end

  def ready_image(target_region, target_image)
    return if target_image.state.to_sym == :available

    # In order to use the 'wait_until_ready_image' method from aws driver, we need to have an image_spec
    # so we create a 'fake' one.
    target_image_spec = Chef::Provisioning::MachineImageSpec.new(
        new_resource.managed_entry_store, :machine_image, @target_name, {})

    # 300 seconds it's not enough to copy an image
    Chef::Config.chef_provisioning[:image_max_wait_time] = Chef::Config.chef_provisioning[:image_max_wait_time] || 600
    action_handler.report_progress 'Waiting for image to be ready ...'
    driver_for_region(target_region).wait_until_ready_image(action_handler, target_image_spec, target_image)
  end

  def fetch_image_by_id(region, image_id)
    driver_for_region(region).ec2_resource.image(image_id)
  end

  def fetch_image_for_region(target_region)
    image_type = driver_for_region(target_region).ec2_client.describe_images({
      filters: [{ 'name' => 'name', 'values' => [@target_name] }]
    }).images.first

    return nil unless image_type
    fetch_image_by_id(target_region, image_type.image_id)
  end

  def copy_image_to_region(target_region)

    target_description = new_resource.target_description || "[Copied #{@source_image.image_id} from #{@source_region}] #{@target_name}"
    copy_image_result = driver_for_region(target_region).ec2_client.copy_image(
      source_region: @source_region,
      source_image_id: @source_image.image_id,
      name: @target_name,
      description: target_description
    )

    fetch_image_by_id(target_region, copy_image_result.image_id)
  end
end
