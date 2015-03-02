require 'spec_helper'
require 'chef_zero_rspec_helper'
AWS.stub!

describe Chef::Provider::AwsSubnet do
  extend ChefZeroRspecHelper
  let(:new_resource) {
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
    run_context = Chef::RunContext.new(my_node, cookbook_collection, events)
    run_context.chef_provisioning.with_driver 'aws'
    run_context
  }

  subject(:provider) {
    described_class.new(new_resource, run_context)
  }

  when_the_chef_server "is empty" do
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
    end
  end
end
