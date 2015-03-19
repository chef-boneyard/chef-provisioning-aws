require 'spec_helper'
require 'cheffish/rspec/chef_run_support'
require 'chef/provisioning/aws_driver/credentials'

describe 'AWS Security Group' do
  extend Cheffish::RSpec::ChefRunSupport

  when_the_chef_server "exists", :osc_compat => false do

    let(:ec2_client) { double(AWS::EC2::Client) }
    let!(:entry_store) { Chef::Provisioning::ChefManagedEntryStore.new }

    before :each do
      allow_any_instance_of(AWS.config.class).to receive(:ec2_client).and_return(ec2_client)
      allow(Chef::Provisioning::ChefManagedEntryStore).to receive(:new).and_return(entry_store)
      allow_any_instance_of(Chef::Provisioning::AWSDriver::Credentials).to receive(:default)
        .and_return({
          :aws_access_key_id => 'na',
          :aws_secret_access_key => 'na'
        })
    end

    describe "create" do
      let(:vpc_id) { "vpc-12345" }
      let(:vpc_name) { "my_vpc" }
      let(:sg_name) { "test_sg" }
      let(:create_hash) do
        {
          :cidr_block=>"10.0.0.0/24",
          :instance_tenancy=>"default"
        }
      end
      let(:create_resp) do
        resp = AWS::Core::Response.new
        resp.data[:vpc] = {
          :tag_set=>[],
          :vpc_id=>vpc_id,
          :cidr_block=>"10.0.0.0/24",
          :instance_tenancy=>"default"
        }
        resp
      end
      let(:describe_resp) do
        resp = AWS::Core::Response.new
        resp.data[:vpc_set] = [{
          :vpc_id => vpc_id,
          :cidr_block => "10.0.0.0/24",
          :state => 'created',
          :dhcp_options_id => 'yggdrasil',
          :tag_set => [],
          :instance_tenancy => 'default',
          :is_default => true
        }]
        resp.request_type = :describe_vpcs
      end
      let(:sg_create_resp) do
        resp = AWS::Core::Response.new
        resp.data[:group_id] = "sg-09876"
        resp
      end

      before do
        expect(ec2_client).to receive(:create_vpc).with(create_hash).and_return(create_resp)
        expect(ec2_client).to receive(:create_tags).with({
          :resources=>[vpc_id],
          :tags=>[{:key=>"Name", :value=>vpc_name}]
        })
        expect(ec2_client).to receive(:describe_vpcs).with({:vpc_ids=>[vpc_id]})
          .and_return(describe_resp)
        expect(ec2_client).to receive(:create_security_group).with({
          :group_name=>sg_name,
          :description=>sg_name,
          :vpc_id=>vpc_id
        }).and_return(sg_create_resp)
      end

      context "when VPC is supplied as a resource name" do
        it "creates the security group" do
          run_recipe do
            with_driver 'aws::us-west-2'
            aws_vpc "my_vpc" do
              cidr_block '10.0.0.0/24'
            end
            aws_security_group 'test_sg' do
              vpc "my_vpc"
            end
          end

          expect(chef_run).to have_updated('aws_vpc[my_vpc]', :create)
          expect(chef_run).to have_updated('aws_security_group[test_sg]', :create)
        end
      end

      context "when VPC is supplied as a aws object identifier" do
        it "creates the security group" do
          run_recipe do
            with_driver 'aws::us-west-2'
            aws_security_group 'test_sg' do
              vpc "vpc-12345"
            end
          end

          expect(chef_run).to have_updated('aws_vpc[my_vpc]', :create)
          expect(chef_run).to have_updated('aws_security_group[test_sg]', :create)
        end
      end

      context "when VPC is supplied as a chef resource" do
        it "creates the security group" do
          run_recipe do
            with_driver 'aws::us-west-2'
            v = aws_vpc "my_vpc" do
              cidr_block '10.0.0.0/24'
            end
            aws_security_group 'test_sg' do
              vpc v
            end
          end

          expect(chef_run).to have_updated('aws_vpc[my_vpc]', :create)
          expect(chef_run).to have_updated('aws_security_group[test_sg]', :create)
        end
      end

      context "when VPC is supplied as a aws object" do
        it "creates the security group" do
          run_recipe do
            with_driver 'aws::us-west-2'
            v = aws_vpc "my_vpc" do
              cidr_block '10.0.0.0/24'
            end
            aws_security_group 'test_sg' do
              vpc v.aws_object
            end
          end

          expect(chef_run).to have_updated('aws_vpc[my_vpc]', :create)
          expect(chef_run).to have_updated('aws_security_group[test_sg]', :create)
        end
      end

    end

  end
end
