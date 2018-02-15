require 'spec_helper'

describe Chef::Resource::AwsLaunchConfiguration do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "when connected to AWS" do
      let(:image_filters) {
        {
          filters: [
            {
              name: "image-type",
              values: ["machine"]
            },
            {
              name: "state",
              values: ["available"]
            },
            {
              name: "is-public",
              values: ["true"]
            },
            {
              name: "owner-alias",
              values: ["amazon"]
            }
          ]
        }
      }

      it "creates a minimum aws_launch_configuration" do
        expect_recipe {
          ami = driver.ec2_client.describe_images(image_filters).images[0].image_id
          aws_launch_configuration "my-launch-configuration" do
            image ami
            instance_type 't2.micro'
          end
        }.to create_an_aws_launch_configuration("my-launch-configuration").and be_idempotent
      end

      it "accepts base64 encoded user data" do
        expect_recipe {
          ami = driver.ec2_client.describe_images(image_filters).images[0].image_id
          aws_launch_configuration "my-launch-configuration" do
            image ami
            instance_type 't2.micro'
            options({
              user_data: Base64.encode64("echo 1")
            })
          end
        }.to create_an_aws_launch_configuration("my-launch-configuration").and be_idempotent
      end

      it "accepts regular user data" do
        expect_recipe {
          ami = driver.ec2_client.describe_images(image_filters).images[0].image_id
          aws_launch_configuration "my-launch-configuration" do
            image ami
            instance_type 't2.micro'
            options({
              user_data: "echo 1"
            })
          end
        }.to create_an_aws_launch_configuration("my-launch-configuration").and be_idempotent
      end

    end
  end
end
