require 'spec_helper'

describe Chef::Resource::MachineImage do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a VPC and a public subnet" do
      before :all do
        chef_config[:log_level] = :warn
        chef_config[:include_output_after_example] = true
        Chef::Config.chef_provisioning[:machine_max_wait_time] = 300
        Chef::Config.chef_provisioning[:image_max_wait_time] = 600
      end

      purge_all
      setup_public_vpc

      it "machine_image can create an image in the VPC", :super_slow do
        expect_recipe {
          machine_image 'test_machine_image' do
            machine_options bootstrap_options: {
              subnet_id: 'test_public_subnet',
              key_name: 'test_key_pair',
              instance_type: 'm3.medium'
            },
            ssh_options: {
              timeout: 60
            }
          end
        }.to create_an_aws_image('test_machine_image',
          name: 'test_machine_image'
        ).and be_idempotent
      end

      describe 'action :destroy', :super_slow do
        # with_converge does a before(:each)
        with_converge {
          machine_image 'test_machine_image' do
            machine_options bootstrap_options: {
              subnet_id: 'test_public_subnet',
              key_name: 'test_key_pair',
              instance_type: 'm3.medium'
            },
            ssh_options: {
              timeout: 60
            }
          end
        }

        it "destroys the image" do
          r = recipe {
            machine_image "test_machine_image" do
              action :destroy
            end
          }
          expect(r).to destroy_an_aws_image('test_machine_image'
          ).and be_idempotent
        end

        it "destroys the image if instance is gone long time ago" do
          image = driver.ec2_resource.images({filters: [ { name: "name", values: ["test_machine_image"] }]}).first
          image.create_tags(tags: [{key: "from-instance", value: "i-12345678"}])

          r = recipe {
            machine_image "test_machine_image" do
              action :destroy
            end
          }
          expect(r).to destroy_an_aws_image('test_machine_image'
          ).and be_idempotent
        end
      end

      it "creates aws_image tags", :super_slow do
        expect_recipe {
          machine_image 'test_machine_image' do
            machine_options bootstrap_options: {
              key_name: 'test_key_pair',
              instance_type: 'm3.medium'
            },
            ssh_options: {
              timeout: 60
            }
            aws_tags key1: "value"
          end
        }.to create_an_aws_image('test_machine_image'
        ).and have_aws_image_tags('test_machine_image',
          {
            'key1' => 'value'
          }
        ).and be_idempotent
      end

      context "with existing tags" do
        machine_image 'test_machine_image' do
          machine_options bootstrap_options: {
            key_name: 'test_key_pair',
            instance_type: 'm3.medium'
          },
          ssh_options: {
            timeout: 60
          }
          aws_tags key1: "value"
        end

        it "updates aws_image tags", :super_slow do
          expect_recipe {
            machine_image 'test_machine_image' do
              aws_tags key1: "value2", key2: nil
            end
          }.to have_aws_image_tags('test_machine_image',
            {
              'key1' => 'value2',
              'key2' => ''
            }
          ).and be_idempotent
        end

        it "removes all aws_image tags", :super_slow do
          expect_recipe {
            machine_image 'test_machine_image' do
              aws_tags({})
            end
          }.to have_aws_image_tags('test_machine_image',
            {}
          ).and be_idempotent
        end
      end

    end
  end
end
