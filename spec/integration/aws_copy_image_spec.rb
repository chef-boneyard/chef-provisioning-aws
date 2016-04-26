require 'spec_helper'

def driver_url_for_region(target_region)
  _, profile_name, _ = driver.driver_url.split(':')
  "aws:#{profile_name}:#{target_region}"
end

def driver_for_region(target_region)
  Chef::Provisioning::AWSDriver::Driver.new(driver_url_for_region(target_region), driver.config)
end

def get_images_for_name(region, name)
  driver_for_region(region).ec2_client.describe_images({ filters: [{ 'name' => 'name', 'values' => [name] }] }).images
end

def deregister_image(region, name)
  image_type = get_images_for_name(region, name).first
  if image_type
    image = driver_for_region(region).ec2_resource.image(image_type.image_id)
    if image.exists?
      begin
        image.deregister
        Chef::Log.info "Image #{image_type.image_id} deregistered."
      rescue Aws::EC2::Errors::AuthFailure
      end
    end
  end
end

describe Chef::Resource::AwsCopyImage do
  extend AWSSupport

  when_the_chef_12_server 'exists', organization: 'foo', server_scope: :context do
    with_aws '' do
      amis = {
        'us-east-1' => 'ami-cb2305a1',
        'us-west-1' => 'ami-bdafdbdd',
        'us-west-2' => 'ami-ec75908c',
      }

      ami_name = 'amzn-ami-2015.09.e-amazon-ecs-optimized'
      source_region = driver.aws_config.region
      target_region = (amis.keys - [source_region]).sample

      context 'with a VPC and a public subnet' do
        before :all do
          chef_config[:log_level] = :warn
          chef_config[:include_output_after_example] = true
          Chef::Config.chef_provisioning[:machine_max_wait_time] = 300
          Chef::Config.chef_provisioning[:image_max_wait_time] = 600
        end

        purge_all
        setup_public_vpc

        image_name = 'test_machine_image'

        machine_image 'test_machine_image' do
          machine_options bootstrap_options: {
            subnet_id: 'test_public_subnet',
            key_name: 'test_key_pair',
            instance_type: 't2.micro'
          },
          ssh_options: {
            timeout: 60
          }
        end

        before :each do
          @test_machine_image_aws_object = test_machine_image.aws_object
        end

        after :each do
          deregister_image(target_region, image_name)
        end

        it "aws_copy_image copies the image from the source region (#{source_region}) to another (#{target_region})."\
        " Target region: #{target_region}", :super_slow do
          converge {
            aws_copy_image image_name do
              destination_region target_region
            end
          }

          image_type = get_images_for_name(target_region, image_name).first
          expect(image_type.name).to eq(image_name)
          expect(image_type.state).to eq('available')
          expect(image_type.description).to eq(
            "[Copied #{@test_machine_image_aws_object.image_id} from #{source_region}] #{image_name}"
          )
        end
      end

      context 'using an pre-existent AMI' do
        ami_id = amis[source_region]
        @target_name = nil

        after :each do
          deregister_image(target_region, @target_name)
        end

        it 'do not copy the image because when already exists one with the same name in the target region' do
          @target_name = ami_name

          images = get_images_for_name(target_region, @target_name)
          image_id = images.first.image_id

          converge {
            aws_copy_image ami_id do
              destination_region target_region
            end
          }

          images = get_images_for_name(target_region, @target_name)
          expect(images.length).to eq(1)
          expect(images.first.image_id).to eq(image_id)
        end

        it "copies the ami when a different name is given to the target image. Target region: #{target_region}",
           :super_slow do
          image_name = 'test_machine_image_with_a_target_name'

          images = get_images_for_name(target_region, image_name)
          expect(images.length).to eq(0)

          converge {
            aws_copy_image ami_id do
              target_name image_name
              destination_region target_region
            end
          }

          @target_name = image_name

          images = get_images_for_name(target_region, image_name)
          expect(images.length).to eq(1)
          expect(images.first.description).to eq("[Copied #{ami_id} from #{source_region}] #{image_name}")
        end
      end
    end
  end
end
