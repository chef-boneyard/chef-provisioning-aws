require 'spec_helper'
require 'chef_zero_rspec_helper'
AWS.stub!

describe Chef::Provider::AwsRdsDbSubnetGroup do
  extend ChefZeroRspecHelper

  let(:new_resource) { 
    resource = Chef::Resource::AwsRdsDbSubnetGroup.new('new_subnet_group', run_context)
    resource.driver 'aws'
    resource
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

  when_the_chef_server 'is empty' do
    
    describe '#action_create' do
      it 'requires a description' do
        expect { provider.action_create }
          .to raise_error(
            RuntimeError, "Can't create a subnet group without a description"
          )
      end

      it 'should create new db subnet group' do
        allow_any_instance_of(AWS::RDS::Client::V20140901)
          .to receive(:describe_db_subnet_groups)
          .and_return(:data => { :db_subnet_groups => []})
        
        allow_any_instance_of(AWS::EC2::SubnetCollection)
          .to receive(:with_tag)
          .and_return([AWS::EC2::Subnet.new('subnet-12345678')])

        allow_any_instance_of(AWS::RDS::Client::V20140901)
          .to receive(:create_db_subnet_group)
          .and_return({})

        new_resource.description('subnet_group_description')
        new_resource.subnets(['subnet-12345678'])
        expect(new_resource).to receive(:save)
        provider.action_create
      end

      it 'should not converge when subnet group already exists' do
        allow_any_instance_of(AWS::RDS::Client::V20140901)
          .to receive(:describe_db_subnet_groups)
          .and_return(:data => { :db_subnet_groups => [{}]})

        new_resource.description('subnet_group_description')

        expect(new_resource).to_not receive(:save)
        provider.action_create
      end
    end
  end
end