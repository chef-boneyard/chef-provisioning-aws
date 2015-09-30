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

      it "respects the network_interfaces block with maximum attributes", :super_slow do
        private_ip_address_start = Random.rand(30)+10
        expect_recipe {
          machine "test_machine" do
            machine_options bootstrap_options: {
              key_name: 'test_key_pair',
              instance_type: 'm3.medium',
              network_interfaces: [
                {
                  # Cannot set associate_public_ip_address and network_interface_id
                  # network_interface_id: "eth0",
                  device_index: 0,
                  subnet_id: test_public_subnet.aws_object.id,
                  description: "network interface description",
                  private_ip_address: "10.0.0.#{private_ip_address_start}",
                  delete_on_termination: true,
                  groups: [test_security_group.aws_object.id],
                  private_ip_addresses: [
                    {
                      private_ip_address: "10.0.0.#{private_ip_address_start+1}",
                      primary: false
                    },
                    {
                      private_ip_address: "10.0.0.#{private_ip_address_start+2}",
                      primary: false
                    }
                  ],
                  # cannot specify both `private_ip_addresses` and `secondary_private_ip_address_count`
                  #secondary_private_ip_address_count: 2,
                  associate_public_ip_address: true
                }
              ]
            }
            action :ready
          end
        }.to create_an_aws_instance("test_machine",
          network_interfaces: [{
            network_interface_id: /^eni-/,
            subnet_id: test_public_subnet.aws_object.id,
            vpc_id: test_vpc.aws_object.id,
            description: "network interface description",
            status: "in-use",
            private_ip_address: "10.0.0.#{private_ip_address_start}",
            groups: [{group_name: 'test_security_group'}],
            attachment: {
              device_index: 0,
              delete_on_termination: true,
              status: "attached"
            },
            private_ip_addresses: [
              {
                private_ip_address: "10.0.0.#{private_ip_address_start}",
                primary: true,
                # the action must be :ready to give the public ip time to be assigned
                association: {
                  public_ip: /\d+/
                }
              },
              {
                private_ip_address: "10.0.0.#{private_ip_address_start+1}",
                primary: false
              },
              {
                private_ip_address: "10.0.0.#{private_ip_address_start+2}",
                primary: false
              }
            ]
          }]
        ).and be_idempotent
      end

      it "converts associate_public_ip_address at the top level to the network interface", :super_slow do
        private_ip_address_start = Random.rand(30)+10
        expect_recipe {
          machine "test_machine" do
            machine_options bootstrap_options: {
              key_name: 'test_key_pair',
              instance_type: 'm3.medium',
              associate_public_ip_address: true,
              subnet_id: test_public_subnet.aws_object.id,
              security_group_ids: [test_security_group.aws_object.id],
              private_ip_address: "10.0.0.#{private_ip_address_start}"
            }
            action :ready
          end
        }.to create_an_aws_instance("test_machine",
          network_interfaces: [{
            network_interface_id: /^eni-/,
            subnet_id: test_public_subnet.aws_object.id,
            vpc_id: test_vpc.aws_object.id,
            status: "in-use",
            private_ip_address: "10.0.0.#{private_ip_address_start}",
            groups: [{group_name: 'test_security_group'}],
            attachment: {
              device_index: 0,
              delete_on_termination: true,
              status: "attached"
            },
            private_ip_addresses: [
              {
                private_ip_address: "10.0.0.#{private_ip_address_start}",
                primary: true,
                association: {
                  public_ip: /\d+/
                }
              }
            ]
          }]
        ).and be_idempotent
      end

      context "with a placement group" do
        before(:context) {
          driver.ec2_client.create_placement_group({
            group_name: "agroup",
            strategy: "cluster"
          })
        }

        # Must do after the context so we have waited for the instance to terminate
        after(:context) {
          driver.ec2_client.delete_placement_group group_name: "agroup"
        }

        it "converts V1 keys to V2 keys", :super_slow do
          expect_recipe {
            machine "test_machine" do
              machine_options bootstrap_options: {
                key_name: 'test_key_pair',
                instance_type: 'm4.large',
                monitoring_enabled: false,
                availability_zone: test_public_subnet.aws_object.availability_zone_name,
                placement_group: "agroup",
                dedicated_tenancy: false, # cannot do true, was getting API error
                subnet: 'test_public_subnet'
              }
              action :allocate
            end
          }.to create_an_aws_instance("test_machine",
            monitoring: {state: "disabled"},
            placement: {
              availability_zone: test_public_subnet.aws_object.availability_zone_name,
              group_name: "agroup",
              tenancy: "default",
            },
            subnet_id: test_public_subnet.aws_object.id
          ).and be_idempotent
        end
	  end

      context "with a custom iam role" do
        # TODO when we have IAM support, use the resources
        before(:context) do
          assume_role_policy_document = '{"Version":"2008-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":["ec2.amazonaws.com"]},"Action":["sts:AssumeRole"]}]}'
          driver.iam_client.create_role({
            role_name: "machine_test_custom_role",
            assume_role_policy_document: assume_role_policy_document
          }).role
          driver.iam_client.create_instance_profile({
            instance_profile_name: "machine_test_custom_role"
          })
          driver.iam_client.add_role_to_instance_profile({
            instance_profile_name: "machine_test_custom_role",
            role_name: "machine_test_custom_role"
          })
          sleep 5 # grrrrrr, the resource should take care of the polling for us
        end

        after(:context) do
          driver.iam_client.remove_role_from_instance_profile({
            instance_profile_name: "machine_test_custom_role",
            role_name: "machine_test_custom_role"
          })
          driver.iam_client.delete_instance_profile({
            instance_profile_name: "machine_test_custom_role"
          })
          driver.iam_client.delete_role({
            role_name: "machine_test_custom_role"
          })
        end

        it "converts iam_instance_profile from a string to a hash", :super_slow do
          expect_recipe {
            machine 'test_machine' do
              machine_options bootstrap_options: {
                subnet_id: 'test_public_subnet',
                key_name: 'test_key_pair',
                iam_instance_profile: "machine_test_custom_role"
              }
              action :allocate
            end
          }.to create_an_aws_instance('test_machine',
            iam_instance_profile: {arn: /machine_test_custom_role/}
          ).and be_idempotent
        end
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
              action :allocate
            end
          }.to create_an_aws_instance('test_machine'
          ).and be_idempotent
        end
      end

    end
  end
end
