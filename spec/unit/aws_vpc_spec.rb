require 'spec_helper'
require 'cheffish/rspec/chef_run_support'
require 'chef/provisioning/aws_driver/credentials'

describe 'Aws VPC' do
  extend Cheffish::RSpec::ChefRunSupport

  before :each do
    AWS.stub!
  end

  when_the_chef_12_server "exists" do
    organization 'foo'

    let(:ec2_client) { double(AWS::EC2::Client) }
    let!(:entry_store) { Chef::Provisioning::ChefManagedEntryStore.new }

    before :each do
      Chef::Config.chef_server_url = URI.join(Chef::Config.chef_server_url, '/organizations/foo').to_s
      allow_any_instance_of(AWS.config.class).to receive(:ec2_client).and_return(ec2_client)
      allow(Chef::Provisioning::ChefManagedEntryStore).to receive(:new).and_return(entry_store)
      allow_any_instance_of(Chef::Provisioning::AWSDriver::Credentials).to receive(:default)
        .and_return({
          :aws_access_key_id => 'na',
          :aws_secret_access_key => 'na'
        })
    end

    let(:vpc_id) { "foo" }

    describe "action :create" do

      let(:create_hash) do
        {
          :cidr_block=>"10.0.31.0/24",
          :instance_tenancy=>"default"
        }
      end
      let(:create_resp) do
        resp = AWS::Core::Response.new
        resp.data[:vpc] = {
          :tag_set=>[],
          :vpc_id=>vpc_id,
          :cidr_block=>"10.0.31.0/24",
          :instance_tenancy=>"default"
        }
        resp
      end

      before do
        expect(ec2_client).to receive(:create_vpc).with(create_hash).and_return(create_resp)
        expect(ec2_client).to receive(:create_tags).with({
          :resources=>[vpc_id],
          :tags=>[{:key=>"Name", :value=>"my_vpc"}]
        })

        expect(entry_store).to receive(:save_data).with(
          "aws_vpc",
          "my_vpc",
          {"reference"=>{"id"=>vpc_id}, "driver_url"=>"aws::us-west-2"},
          kind_of(Chef::Provisioning::ActionHandler)
        )
      end

      after do
        expect(chef_run).to have_updated('aws_vpc[my_vpc]', :create)
      end

      context "simple object" do
        it "creates the VPC" do
          run_recipe do
            with_driver 'aws::us-west-2'
            aws_vpc 'my_vpc' do
              cidr_block '10.0.31.0/24'
            end
          end
        end
      end

      context "internet gateway" do
        let(:internet_gateway_id) {"stargate"}
        before do
          resp = AWS::Core::Response.new
          resp.data[:internet_gateway_set] = []
          expect(ec2_client).to receive(:describe_internet_gateways).exactly(2).times
            .with({:filters=>[{:name=>"attachment.vpc-id", :values=>[vpc_id]}]})
            .and_return(resp)
          resp = AWS::Core::Response.new
          resp.data[:internet_gateway] = {
            :internet_gateway_id => internet_gateway_id
          }
          expect(ec2_client).to receive(:create_internet_gateway).and_return(resp)
          expect(ec2_client).to receive(:create_tags).with({
            :resources=>["stargate"],
            :tags=>[{:key=>"OwnedByVPC", :value=>vpc_id}]
          })
          expect(ec2_client).to receive(:attach_internet_gateway)
            .with({:internet_gateway_id=>"stargate", :vpc_id=>vpc_id})
        end
        it "creates the VPC" do
          run_recipe do
            with_driver 'aws::us-west-2'
            aws_vpc 'my_vpc' do
              cidr_block '10.0.31.0/24'
              internet_gateway true
            end
          end
        end
      end

      context "enable_dns_support" do
        before do
          resp = AWS::Core::Response.new
          resp.data[:vpc_id] = vpc_id
          resp.data[:enable_dns_support] = {:value => false}
          resp.data[:enable_dns_hostnames] = {:value => false}
          expect(ec2_client).to receive(:describe_vpc_attribute)
            .with({:vpc_id=>vpc_id, :attribute=>"enableDnsSupport"})
            .and_return(resp)
          resp = AWS::Core::Response.new
          expect(ec2_client).to receive(:modify_vpc_attribute)
            .with({:vpc_id=>vpc_id, :enable_dns_support=>{:value=>true}})
            .and_return(resp)
        end
        it "creates the VPC" do
          run_recipe do
            with_driver 'aws::us-west-2'
            aws_vpc 'my_vpc' do
              cidr_block '10.0.31.0/24'
              enable_dns_support true
            end
          end
        end
      end

      context "enable_dns_hostnames" do
        before do
          resp = AWS::Core::Response.new
          resp.data[:vpc_id] = vpc_id
          resp.data[:enable_dns_support] = {:value => false}
          resp.data[:enable_dns_hostnames] = {:value => false}
          expect(ec2_client).to receive(:describe_vpc_attribute)
            .with({:vpc_id=>vpc_id, :attribute=>"enableDnsHostnames"})
            .and_return(resp)
          resp = AWS::Core::Response.new
          expect(ec2_client).to receive(:modify_vpc_attribute)
            .with({:vpc_id=>vpc_id, :enable_dns_hostnames=>{:value=>true}})
            .and_return(resp)
        end
        it "creates the VPC" do
          run_recipe do
            with_driver 'aws::us-west-2'
            aws_vpc 'my_vpc' do
              cidr_block '10.0.31.0/24'
              enable_dns_hostnames true
            end
          end
        end
      end

    end

    describe "when supplying an existing vpc_id" do
      before do
        resp = AWS::Core::Response.new
        resp.data[:vpc_set] = [{
          :vpc_id => 'vpc-123456',
          :cidr_block => '10.0.31.0/24',
          :state => 'created',
          :dhcp_options_id => 'yggdrasil',
          :tag_set => [],
          :instance_tenancy => 'default',
          :is_default => true
        }]
        resp.request_type = :describe_vpcs
        expect(ec2_client).to receive(:describe_vpcs).exactly(2).times
          .with({:vpc_ids=>['vpc-123456']})
          .and_return(resp)
      end
      it "finds the VPC without updating it" do
        run_recipe do
          with_driver 'aws::us-west-2'
          aws_vpc 'my_vpc' do
            cidr_block '10.0.31.0/24'
            vpc_id 'vpc-123456'
          end
        end
      end

      it "errors when trying to update the cidr_block" do
        expect {
          run_recipe do
            with_driver 'aws::us-west-2'
            aws_vpc 'my_vpc' do
              cidr_block '10.0.32.0/24'
              vpc_id 'vpc-123456'
            end
          end
        }.to raise_exception(/VPC CIDR blocks cannot currently be changed!/)
      end

      it "errors when trying to update the instance_tenancy" do
        expect {
          run_recipe do
            with_driver 'aws::us-west-2'
            aws_vpc 'my_vpc' do
              cidr_block '10.0.31.0/24'
              instance_tenancy :dedicated
              vpc_id 'vpc-123456'
            end
          end
        }.to raise_exception(/Instance tenancy of VPCs cannot be changed!/)
      end

      it "successfully updates attributes" do
        resp = AWS::Core::Response.new
        resp.data[:vpc_id] = vpc_id
        resp.data[:enable_dns_hostnames] = {:value => false}
        expect(ec2_client).to receive(:describe_vpc_attribute)
          .with({:vpc_id=>'vpc-123456', :attribute=>"enableDnsHostnames"})
          .and_return(resp)
        resp = AWS::Core::Response.new
        expect(ec2_client).to receive(:modify_vpc_attribute)
          .with({:vpc_id=>'vpc-123456', :enable_dns_hostnames=>{:value=>true}})
          .and_return(resp)
        run_recipe do
          with_driver 'aws::us-west-2'
          aws_vpc 'my_vpc' do
            cidr_block '10.0.31.0/24'
            enable_dns_hostnames true
            vpc_id 'vpc-123456'
          end
        end
      end
    end

    describe "action :destroy" do
      let(:ig_id) {"bar"}

      shared_examples "deletes VPC" do
        it "deletes VPC" do
          resp = {"id"=>"my_vpc", "reference"=>{"id"=>"foo"}, "driver_url"=>"aws::us-west-2"}
          expect(entry_store).to receive(:get_data).with(:aws_vpc, "my_vpc").and_return(resp)
          expect(ec2_client).to receive(:describe_vpcs).with({:vpc_ids=>[vpc_id]}).and_return(true)
          expect(ec2_client).to receive(:destroy_vpc).with({:vpc_id=>vpc_id})

          run_recipe do
            with_driver 'aws::us-west-2'
            aws_vpc 'my_vpc' do
              action :destroy
            end
          end

          expect(chef_run).to have_updated('aws_vpc[my_vpc]', :destroy)
        end
      end

      context "no internet gateway" do
        before do
          resp = AWS::Core::Response.new
          resp.data[:internet_gateway_set] = []
          expect(ec2_client).to receive(:describe_internet_gateways)
            .with({:filters=>[{:name=>"attachment.vpc-id", :values=>[vpc_id]}]})
            .and_return(resp)
        end
        include_examples "deletes VPC"
      end

      context "a managed Internet Gateway" do
        before do
          resp = AWS::Core::Response.new
          resp.data[:internet_gateway_set] = [{
            :internet_gateway_id => ig_id
          }]
          expect(ec2_client).to receive(:describe_internet_gateways)
            .with({:filters=>[{:name=>"attachment.vpc-id", :values=>[vpc_id]}]})
            .and_return(resp)
          expect(ec2_client).to receive(:detach_internet_gateway).with({
            :internet_gateway_id=>ig_id,
            :vpc_id=>vpc_id
          })
          tag = {
            :resource_id => ig_id,
            :resource_type => "internet-gateway",
            :key => "OwnedByVPC",
            :value => vpc_id
          }
          resp = AWS::Core::Response.new
          resp.data[:tag_set] = [tag]
          resp.data[:tag_index] = {
            "internet-gateway:#{ig_id}:OwnedByVPC" => tag
          }
          resp.request_type = :describe_tags
          resp.tag_index["internet-gateway:bar:OwnedByVPC"]
          expect(ec2_client).to receive(:describe_tags).with({
            :filters=>[
              {:name=>"key", :values=>["OwnedByVPC"]},
              {:name=>"resource-type", :values=>["internet-gateway"]},
              {:name=>"resource-id", :values=>[ig_id]}
            ]
          }).and_return(resp)
          expect(ec2_client).to receive(:destroy_internet_gateway).with({:internet_gateway_id=>ig_id})
        end
        include_examples "deletes VPC"
      end

      context "an unmanaged Internet Gateway" do
        before do
          resp = AWS::Core::Response.new
          resp.data[:internet_gateway_set] = [{
            :internet_gateway_id => ig_id
          }]
          expect(ec2_client).to receive(:describe_internet_gateways)
            .with({:filters=>[{:name=>"attachment.vpc-id", :values=>[vpc_id]}]})
            .and_return(resp)
          expect(ec2_client).to receive(:detach_internet_gateway).with({
            :internet_gateway_id=>ig_id,
            :vpc_id=>vpc_id
          })
          resp = AWS::Core::Response.new
          resp.data[:tag_set] = []
          expect(ec2_client).to receive(:describe_tags).with({
            :filters=>[
              {:name=>"key", :values=>["OwnedByVPC"]},
              {:name=>"resource-type", :values=>["internet-gateway"]},
              {:name=>"resource-id", :values=>[ig_id]}
            ]
          }).and_return(resp)
        end
        include_examples "deletes VPC"
      end

    end
  end
end
