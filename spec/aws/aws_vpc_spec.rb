require 'spec_helper'
require 'chef/provisioning/aws_driver/credentials'

describe 'Aws VPC' do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "without a VPC" do

      it "aws_security_group 'test-sg' with no attributes works" do
        expect {
          aws_security_group 'test-sg' do
          end
        }.to cause_an_update.and be_idempotent

        expect(security_group.aws_object.exists?).to be_truthy
      end

    end

    with_aws "in a VPC" do
      aws_vpc 'test-vpc' do
        cidr_block '10.0.0.0/24'
      end

      it "aws_security_group 'test-sg' with no attributes works" do
        expect {
          aws_security_group 'test-sg' do
            vpc 'test-vpc'
          end
        }.to cause_an_update.and be_idempotent

        sg = security_group.aws_object

        expect(sg.exists?).to be_truthy
        expect(sg.name).to eq 'test-sg'
        expect(sg.description).to eq 'test-sg'
        expect(sg.vpc_id).to eq vpc.aws_object.id
        expect(sg.ip_permissions_list).to eq []
        expect(sg.ip_permissions_list_egress).to eq [{:groups=>[], :ip_ranges=>[{:cidr_ip=>"0.0.0.0/0"}], :ip_protocol=>"-1"}]
      end

      it "aws_security_group 'test-sg' with inbound rules works" do
        expect {
          aws_security_group 'test-sg' do
            vpc 'test-vpc'
            inbound_rules [ { ports: 22, protocol: :tcp, sources: [ '10.0.0.0/0' ] } ]
          end
        }.to cause_an_update.and be_idempotent

        sg = security_group.aws_object

        expect(sg.exists?).to be_truthy
        expect(sg.name).to eq 'test-sg'
        expect(sg.description).to eq 'test-sg'
        expect(sg.vpc_id).to eq vpc.aws_object.id
        expect(sg.ip_permissions_list).to eq [{:groups=>[], :ip_ranges=>[{:cidr_ip=>"0.0.0.0/0"}], :ip_protocol=>"tcp", :from_port=>22, :to_port=>22}]
        expect(sg.ip_permissions_list_egress).to eq [{:groups=>[], :ip_ranges=>[{:cidr_ip=>"0.0.0.0/0"}], :ip_protocol=>"-1"}]
      end
    end
  end
end
