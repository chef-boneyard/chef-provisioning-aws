require 'spec_helper'
require 'cheffish/rspec/chef_run_support'

describe 'Aws VPC' do
  extend Cheffish::RSpec::ChefRunSupport

  when_the_chef_12_server "exists" do
    organization 'foo'

    let(:ec2_client) { double(AWS::EC2::Client) }
    #let!(:foo) { AWS.config.ec2_client }
    let(:entry_store) { Chef::Provisioning::ChefManagedEntryStore.new }

    before :each do
      Chef::Config.chef_server_url = URI.join(Chef::Config.chef_server_url, '/organizations/foo').to_s
      allow_any_instance_of(AWS.config.class).to receive(:ec2_client).and_return(ec2_client)
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

      run_recipe do
        with_driver 'aws::us-west-2'
        aws_vpc 'my_vpc' do
          cidr_block '10.0.31.0/24'
        end
      end

      expect(chef_run).to have_updated('aws_vpc[my_vpc]', :create)
      expect(entry_store.get_data('aws_vpc', 'my_vpc')).to eq(
        {"id"=>"my_vpc", "reference"=>{"id"=>"foo"}, "driver_url"=>"aws::us-west-2"}
      )
    end
  end
end
