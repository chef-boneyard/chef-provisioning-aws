require 'spec_helper'
require 'chef/resource/aws_security_group'
require 'chef/provisioning/aws_driver/exceptions'

describe Chef::Resource::AwsSecurityGroup do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "without a VPC" do

      it "aws_security_group 'test_sg' with no attributes works" do
        expect_recipe {
          aws_security_group 'test_sg' do
          end
        }.to create_an_aws_security_group('test_sg',
          description:                'test_sg',
          vpc_id:                     default_vpc.id,
          ip_permissions_list:        [],
          ip_permissions_list_egress: [{:groups=>[], :ip_ranges=>[{:cidr_ip=>"0.0.0.0/0"}], :ip_protocol=>"-1"}]
        ).and be_idempotent
      end

      it "can reference a security group by name or id" do
        expect_recipe {
          sg = aws_security_group 'test_sg'
          sg.run_action(:create)
          id = sg.aws_object.id
          aws_security_group id do
            inbound_rules '0.0.0.0/0' => 22
          end
          aws_security_group 'test_sg' do
            security_group_id id
            outbound_rules 22 => '0.0.0.0/0'
          end
        }.to create_an_aws_security_group('test_sg',
          description:                'test_sg',
          vpc_id:                     default_vpc.id,
          ip_permissions_list: [
            { groups: [], ip_ranges: [{cidr_ip: "0.0.0.0/0"}],  ip_protocol: "tcp", from_port: 22, to_port: 22},
          ],
          ip_permissions_list_egress: [
            {groups: [], ip_ranges: [{cidr_ip: "0.0.0.0/0"}], ip_protocol: "tcp", from_port: 22, to_port: 22 }
          ]

        ).and be_idempotent
      end

      it "raises an error trying to reference a security group by an unknown id" do
        expect_converge {
          aws_security_group 'sg-12345678'
        }.to raise_error(RuntimeError, /Chef::Resource::AwsSecurityGroup\[sg-12345678\] does not exist!/)
        expect_converge {
          aws_security_group 'test_sg' do
            security_group_id 'sg-12345678'
          end
        }.to raise_error(RuntimeError, /Chef::Resource::AwsSecurityGroup\[sg-12345678\] does not exist!/)
      end

      it "creates aws_security_group tags" do
        expect_recipe {
          aws_security_group 'test_sg' do
            aws_tags key1: "value"
          end
        }.to create_an_aws_security_group('test_sg')
        .and have_aws_security_group_tags('test_sg',
          {
            'Name' => 'test_sg',
            'key1' => 'value'
          }
        ).and be_idempotent
      end

      context "with existing tags" do
        aws_security_group 'test_sg' do
          aws_tags key1: "value"
        end

        it "updates aws_security_group tags" do
          expect_recipe {
            aws_security_group 'test_sg' do
              aws_tags key1: "value2", key2: nil
            end
          }.to have_aws_security_group_tags('test_sg',
            {
              'Name' => 'test_sg',
              'key1' => 'value2',
              'key2' => ''
            }
          ).and be_idempotent
        end

        it "removes all aws_security_group tags except Name" do
          expect_recipe {
            aws_security_group 'test_sg' do
              aws_tags {}
            end
          }.to have_aws_security_group_tags('test_sg',
            {
              'Name' => 'test_sg'
            }
          ).and be_idempotent
        end
      end

    end

    with_aws "in a VPC" do
      aws_vpc 'test_vpc' do
        cidr_block '10.0.0.0/24'
      end

      it "aws_security_group 'test_sg' with no attributes works" do
        expect_recipe {
          aws_security_group 'test_sg' do
            vpc 'test_vpc'
          end
        }.to create_an_aws_security_group('test_sg',
          vpc_id:                     test_vpc.aws_object.id,
          ip_permissions_list:        [],
          ip_permissions_list_egress: [{:groups=>[], :ip_ranges=>[{:cidr_ip=>"0.0.0.0/0"}], :ip_protocol=>"-1"}]
        ).and be_idempotent
      end

      it "aws_security_group 'test_sg' with inbound and outbound rules works" do
        expect_recipe {
          aws_security_group 'test_sg' do
            vpc 'test_vpc'
            inbound_rules '0.0.0.0/0' => 22
            outbound_rules 22 => '0.0.0.0/0'
          end
        }.to create_an_aws_security_group('test_sg',
          vpc_id: test_vpc.aws_object.id,
          ip_permissions_list: [
            { groups: [], ip_ranges: [{cidr_ip: "0.0.0.0/0"}],  ip_protocol: "tcp", from_port: 22, to_port: 22},
          ],
          ip_permissions_list_egress: [{groups: [], ip_ranges: [{cidr_ip: "0.0.0.0/0"}], ip_protocol: "tcp", from_port: 22, to_port: 22 }]
        ).and be_idempotent
      end

      it "aws_security_group 'test_sg' with inbound and outbound rules allowing all ports works when protocol specified" do
        expect_recipe {
        aws_security_group 'test_sg' do
          vpc 'test_vpc'
          inbound_rules('0.0.0.0/0' => { port_range: -1..-1, protocol: -1 })
          outbound_rules({ port_range: -1..-1, protocol: -1 } => '0.0.0.0/0')
        end
        }.to create_an_aws_security_group('test_sg',
          vpc_id: test_vpc.aws_object.id,
          ip_permissions_list: [
            { groups: [], ip_ranges: [{cidr_ip: "0.0.0.0/0"}],  ip_protocol: "-1"}
          ],
          ip_permissions_list_egress: [{ groups: [], ip_ranges: [{cidr_ip: "0.0.0.0/0"}],  ip_protocol: "-1"}]
        ).and be_idempotent
      end
    end

    with_aws "when narrowing from multiple VPCs" do
      aws_vpc 'test_vpc1' do
        cidr_block '10.0.0.0/24'
      end
      aws_vpc 'test_vpc2' do
        cidr_block '10.0.0.0/24'
      end
      aws_security_group 'test_sg' do
        vpc 'test_vpc1'
      end
      aws_security_group 'test_sg' do
        vpc 'test_vpc2'
      end

      # We need to manually delete these because the auto-delete
      # won't specify VPC
      after(:context) do
        converge {
          aws_security_group 'test_sg' do
            vpc 'test_vpc1'
            action :destroy
          end
          aws_security_group 'test_sg' do
            vpc 'test_vpc2'
            action :destroy
          end
        }
      end

      it "raises an error if it finds multiple security groups" do
        expect_converge {
          r = aws_security_group 'test_sg'
          r.aws_object
        }.to raise_error(::Chef::Provisioning::AWSDriver::Exceptions::MultipleSecurityGroupError)
      end

      it "correctly returns the security group when vpc is specified" do
        aws_obj = nil
        expect_converge {
          r = aws_security_group 'test_sg' do
            vpc 'test_vpc1'
          end
          aws_obj = r.aws_object
        }.to_not raise_error
        expect(aws_obj.vpc.tags['Name']).to eq('test_vpc1')
      end
    end

  end
end
