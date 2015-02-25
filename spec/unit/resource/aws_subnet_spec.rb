require 'spec_helper'
require 'chef_zero_rspec_helper'

describe Chef::Resource::AwsSubnet do
  extend ChefZeroRspecHelper
  let(:my_node) { Chef::Node.new() }
  let(:events) { Chef::EventDispatch::Dispatcher.new }
  let(:run_context) { Chef::RunContext.new(my_node,{},events) }

  subject(:resource) {
    described_class.new('my_subnet', run_context)
  }

  when_the_chef_server "is empty" do
    it 'should match resource name' do
      expect(resource.resource_name).to eq(:aws_subnet)
    end

    it 'should match name' do
      expect(resource.name).to eq('my_subnet')
    end
  end
end
