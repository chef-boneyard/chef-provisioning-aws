require 'spec_helper'

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

      it "aws_security_group 'test_sg' with inbound rules works" do
        expect_recipe {
          aws_security_group 'test_sg' do
            vpc 'test_vpc'
            inbound_rules '0.0.0.0/0' => 22,
                          [ { ports: 22, protocol: :tcp, sources: [ '10.0.0.0/0' ] } ]
          end
        }.to create_an_aws_security_group('test_sg',
          vpc_id: test_vpc.aws_object.id,
          ip_permissions_list: [
            { groups: [], ip_ranges: [{cidr_ip: "0.0.0.0/0"}],  ip_protocol: "tcp", from_port: 22, to_port: 22}
            { groups: [], ip_ranges: [{cidr_ip: "10.0.0.0/0"}], ip_protocol: "tcp", from_port: 22, to_port: 22}],
          ip_permissions_list_egress: [{groups: [], ip_ranges: [{cidr_ip: "0.0.0.0/0"}], ip_protocol: "-1"}]
        ).and be_idempotent
      end
    end
  end
end
