require 'spec_helper'

describe Chef::Provider::AwsSubnet do
  let(:new_resource) { Chef::Resource::AwsSubnet.new('newname') }
  let(:node) { Chef::Node.new() }
  let(:events) { Chef::EventDispatch::Dispatcher.new }
  let(:run_context) { Chef::RunContext.new(node,{},events) }
  let(:current_resource) { Chef::Resource::AwsSubnet.new('newname') }

#  let(:data_bag_resource) do
#    Chef::Resource::ChefDataBagResource.new(
#      'string',
#      run_context
#    )
#  end
#    Class.new(Chef::Resource::ChefDataBagResource) do
#      self.resource_name = :sample_resource
#      attribute :food,  'burger'
#    end


  subject(:provider) {
    described_class.new(new_resource, run_context)
  }

  before do # Needed when determining current_resource state
    Chef::Resource::ChefDataBagResource.stub(:new).and_return(nil)
    provider.stub(:load_current_resource).and_return(current_resource)
    provider.new_resource = new_resource
    provider.current_resource = current_resource
  end

  it 'should be instantiated' do
    expect(provider).to respond_to(:new_resource)
    expect(provider).to respond_to(:run_context)
  end
end
