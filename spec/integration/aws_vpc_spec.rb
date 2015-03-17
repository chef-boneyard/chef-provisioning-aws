require 'spec_helper'
require 'cheffish/rspec/chef_run_support'

describe 'Aws VPC' do
  extend Cheffish::RSpec::ChefRunSupport

  when_the_chef_12_server "exists" do
    organization 'foo'

    let(:ec2_client) { double(AWS::EC2::Client) }
    let!(:entry_store) { Chef::Provisioning::ChefManagedEntryStore.new }

    before :each do
      Chef::Config.chef_server_url = URI.join(Chef::Config.chef_server_url, '/organizations/foo').to_s
      allow_any_instance_of(AWS.config.class).to receive(:ec2_client).and_return(ec2_client)
      allow(Chef::Provisioning::ChefManagedEntryStore).to receive(:new).and_return(entry_store)
    end

    it "should create a new instance" do
      resp = AWS::Core::Response.new
      resp.data[:vpc] = {
        :tag_set=>[],
        :vpc_id=>"foo",
        :state=>"pending",
        :cidr_block=>"10.0.31.0/24",
        #:dhcp_options_id=>"dopt-28eefe4a",
        :instance_tenancy=>"default"
      }

      expect(ec2_client).to receive(:create_vpc).with({:cidr_block=>"10.0.31.0/24", :instance_tenancy=>"default"}).and_return(resp)
      expect(ec2_client).to receive(:create_tags).with({:resources=>["foo"], :tags=>[{:key=>"Name", :value=>"my_vpc"}]})
      expect(entry_store).to receive(:save_data).with("aws_vpc", "my_vpc", {"reference"=>{"id"=>"foo"}, "driver_url"=>"aws::us-west-2"}, kind_of(Chef::Provisioning::ActionHandler))

      run_recipe do
        with_driver 'aws::us-west-2'
        aws_vpc 'my_vpc' do
          cidr_block '10.0.31.0/24'
        end
      end

      expect(chef_run).to have_updated('aws_vpc[my_vpc]', :create)
    end

    describe "action :delete" do
      let(:aws_id) {"foo"}
      let(:ig_id) {"bar"}

      shared_examples "deletes VPC" do
        it "deletes VPC" do
          resp = {"id"=>"my_vpc", "reference"=>{"id"=>"foo"}, "driver_url"=>"aws::us-west-2"}
          expect(entry_store).to receive(:get_data).with(:aws_vpc, "my_vpc").and_return(resp)
          expect(ec2_client).to receive(:describe_vpcs).with({:vpc_ids=>[aws_id]}).and_return(true)
          expect(ec2_client).to receive(:delete_vpc).with({:vpc_id=>aws_id})

          run_recipe do
            with_driver 'aws::us-west-2'
            aws_vpc 'my_vpc' do
              action :delete
            end
          end

          expect(chef_run).to have_updated('aws_vpc[my_vpc]', :delete)
        end
      end

      context "no internet gateway" do
        before do
          resp = AWS::Core::Response.new
          resp.data[:internet_gateway_set] = []
          expect(ec2_client).to receive(:describe_internet_gateways)
            .with({:filters=>[{:name=>"attachment.vpc-id", :values=>[aws_id]}]})
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
            .with({:filters=>[{:name=>"attachment.vpc-id", :values=>[aws_id]}]})
            .and_return(resp)
          expect(ec2_client).to receive(:detach_internet_gateway).with({
            :internet_gateway_id=>ig_id,
            :vpc_id=>aws_id
          })
          tag = {
            :resource_id => ig_id,
            :resource_type => "internet-gateway",
            :key => "OwnedByVPC",
            :value => aws_id
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
          expect(ec2_client).to receive(:delete_internet_gateway).with({:internet_gateway_id=>ig_id})
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
            .with({:filters=>[{:name=>"attachment.vpc-id", :values=>[aws_id]}]})
            .and_return(resp)
          expect(ec2_client).to receive(:detach_internet_gateway).with({
            :internet_gateway_id=>ig_id,
            :vpc_id=>aws_id
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
