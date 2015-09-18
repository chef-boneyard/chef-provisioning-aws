require 'spec_helper'
require 'openssl'

describe Chef::Resource::Machine do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a VPC and a public subnet" do

      before :all do
        chef_config[:log_level] = :warn
      end

      purge_all
      setup_public_vpc

      it "machine with few options allocates a machine", :super_slow do
        expect_recipe {
          machine 'test_machine' do
            machine_options bootstrap_options: {
              subnet_id: 'test_public_subnet',
              key_name: 'test_key_pair'
            }
            action :allocate
          end
        }.to create_an_aws_instance('test_machine'
        ).and be_idempotent
      end

      it "machine with few options converges a machine", :super_slow do
        expect_recipe {
          machine 'test_machine' do
            machine_options bootstrap_options: {
              subnet_id: 'test_public_subnet',
              key_name: 'test_key_pair'
            }
            action :allocate
          end
        }.to create_an_aws_instance('test_machine'
        ).and be_idempotent
      end

      it "machine with source_dest_check false creates a machine with no source dest check", :super_slow do
        expect_recipe {
          machine 'test_machine' do
            machine_options bootstrap_options: {
              subnet_id: 'test_public_subnet',
              key_name: 'test_key_pair'
            }, source_dest_check: false
            action :allocate
          end
        }.to create_an_aws_instance('test_machine',
          source_dest_check: false
        ).and be_idempotent
      end

      it "base64 encodes the user data", :super_slow do
        uniq = Random.rand(100)
        expect_recipe {
          machine "test_machine_#{uniq}" do
            machine_options bootstrap_options: {
              subnet_id: 'test_public_subnet',
              key_name: 'test_key_pair',
              user_data: 'echo \'foo\''
            }
            action :allocate
          end
        }.to create_an_aws_instance("test_machine_#{uniq}"
        ).and be_idempotent
        expect(
          driver.ec2_client.describe_instance_attribute(
            instance_id: driver.ec2_resource.instances(filters: [{name: "tag:Name", values:["test_machine_#{uniq}"]}]).first.id,
            attribute: "userData"
          ).user_data.value
        ).to eq("ZWNobyAnZm9vJw==\n")
      end

      it "machine with from_image option is created from correct image", :super_slow do
        expect_recipe {

          machine_image 'test_machine_ami' do
            machine_options bootstrap_options: {
              subnet_id: 'test_public_subnet',
              key_name: 'test_key_pair'
            }
          end

          machine 'test_machine' do
            from_image 'test_machine_ami'
            machine_options bootstrap_options: {
              subnet_id: 'test_public_subnet',
              key_name: 'test_key_pair'
            }
            action :allocate
          end
        }.to create_an_aws_instance('test_machine',
          image_id: driver.ec2.images.filter('name', 'test_machine_ami').first.image_id
        ).and create_an_aws_image('test_machine_ami',
          name: 'test_machine_ami'
        ).and be_idempotent
      end

    end

    with_aws "Without a VPC" do

      before :all do
        chef_config[:log_level] = :warn
      end

      #purge_all
      it "machine with no options creates an machine", :super_slow do
        expect_recipe {
          aws_key_pair 'test_key_pair' do
            allow_overwrite true
          end
          machine 'test_machine' do
            machine_options bootstrap_options: { key_name: 'test_key_pair' }
            action :allocate
          end
        }.to create_an_aws_instance('test_machine'
        ).and create_an_aws_key_pair('test_key_pair'
        ).and be_idempotent
      end

      # Tests https://github.com/chef/chef-provisioning-aws/issues/189
      it "correctly finds the driver_url when switching between machine and aws_instance", :super_slow do
        expect { recipe {
          machine 'test-machine-driver' do
            action :allocate
          end
          aws_instance 'test-machine-driver'
          machine 'test-machine-driver' do
            action :destroy
          end
        }.converge }.to_not raise_error
      end

      # https://github.com/chef/chef-provisioning-aws/pull/295
      context "with a custom key" do
        let(:private_key) {
          k = OpenSSL::PKey::RSA.new(2048)
          f = Pathname.new(private_key_path)
          f.write(k.to_pem)
          k
        }
        let(:public_key) {private_key.public_key}
        let(:private_key_path) {
          Pathname.new(ENV['HOME']).join(".ssh", key_pair_name).expand_path
        }
        let(:key_pair_name) { "test_key_pair_#{Random.rand(100)}" }

        before do
          driver.ec2_client.import_key_pair({
            key_name: key_pair_name, # required
            public_key_material: "#{public_key.ssh_type} #{[public_key.to_blob].pack('m0')}", # required
          })
        end

        after do
          driver.ec2_client.delete_key_pair({
            key_name: key_pair_name, # required
          })
          Pathname.new(private_key_path).delete
        end

        it "strips key_path from the bootstrap options when creating the machine", :super_slow do
          expect_recipe {
            machine 'test_machine' do
              machine_options bootstrap_options: {
                key_name: key_pair_name,
                key_path: private_key_path
              }
            end
          }.to create_an_aws_instance('test_machine'
          ).and be_idempotent
        end
      end

    end
  end
end
