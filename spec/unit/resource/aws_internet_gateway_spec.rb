# TODO: Test for error when this is missing:
#        self.databag_name = 'aws_internet_gateway'
#  or one gets:
#    ArgumentError
#    -------------
#    You must supply a name when declaring a chef_data_bag resource

require 'spec_helper'
require 'chef_zero_rspec_helper'
AWS.stub!

describe Chef::Resource::AwsInternetGateway do
  extend ChefZeroRspecHelper
  let(:my_node) { Chef::Node.new }
  let(:events) { Chef::EventDispatch::Dispatcher.new }
  let(:run_context) { Chef::RunContext.new(my_node, {}, events) }

  let(:resource) do
    described_class.new('my_igw', run_context)
  end

  when_the_chef_server "is empty" do
    it 'should match resource name' do
      expect(resource.resource_name).to eq(:aws_internet_gateway)
    end

    it 'should match name' do
      expect(resource.name).to eq('my_igw')
    end
  end
end
