require 'spec_helper'
require 'chef_zero_rspec_helper'
AWS.stub!

describe Chef::Provider::AwsSubnet do
  extend ChefZeroRspecHelper
  let(:new_resource) {
    Chef::Resource::AwsSubnet.new('my_subnet', run_context)
  }
  # I don't think this next resource is needed because we
  # don't attempt to load the current resource from the
  # databag
  let(:current_resource) {
    Chef::Resource::AwsSubnet.new('my_subnet', run_context)
  }
  let(:my_node) {
    node = Chef::Node.new
    node.automatic['platform'] = 'ubuntu'
    node.automatic['platform_version'] = '12.04'
    node
  }
  let(:events) { Chef::EventDispatch::Dispatcher.new }
  let(:run_context) {
    cookbook_collection = {}
    Chef::RunContext.new(my_node, cookbook_collection ,events)
  }

  subject(:provider) {
    described_class.new(new_resource, run_context)
  }

  # Note the use of 'my_node' above to prevent namespace
  # conflict with the node method of when_the_chef_server
  when_the_chef_server "is empty" do
    before do
#      allow(provider)
#        .to receive(:load_current_resource).and_return(current_resource)
#      provider.new_resource = new_resource
#      provider.current_resource = current_resource
    end

    it 'should be instantiated' do
      expect(provider).to respond_to(:new_resource)
      expect(provider).to respond_to(:run_context)
    end

    describe '#action_create' do
      it 'requires cidr_block' do
        expect{ provider.action_create }
          .to raise_error(
             RuntimeError, "Can't create a Subnet without a CIDR block"
          )
      end

      it 'requires VPC to exist' do
        new_resource.cidr_block('1.2.3.4/24')
        new_resource.vpc('my_vpc')
        expect{ provider.action_create }
          .to raise_error(AWS::Core::OptionGrammar::FormatError)
      end

      it 'fails because there is no VPC object' do
        new_resource.cidr_block('1.2.3.4/24')
        new_resource.vpc('my_vpc')
        allow_any_instance_of(AWS::EC2::VPCCollection)
          .to receive(:with_tag)
          .and_return(nil)
        expect{ provider.action_create }
          .to raise_error(AWS::Core::OptionGrammar::FormatError)
      end

      it 'should work with a VPC object' do
        new_resource.cidr_block('1.2.3.4/24')
        allow_any_instance_of(AWS::EC2::VPCCollection)
          .to receive(:with_tag)
          .and_return( [ AWS::EC2::VPC.new('vpc-abcd1234') ] )
        allow_any_instance_of(AWS::EC2::SubnetCollection)
          .to receive(:create)
          .and_return(AWS::EC2::Subnet.new('subnet-feeddeed'))
        expect(new_resource).to receive(:save)
        provider.action_create
      end

      it 'should not converge if subnet already exists' do
        new_resource.cidr_block('1.2.3.4/24')
        allow_any_instance_of(AWS::EC2::SubnetCollection)
          .to receive(:with_tag)
          .and_return([AWS::EC2::Subnet.new('subnet-feeddeed')])
        expect(provider).to_not receive(:converge_by)
        provider.action_create
      end

    end # #action_create
  end # when_the_chef_server is empty
end
