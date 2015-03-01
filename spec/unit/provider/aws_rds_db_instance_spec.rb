require 'spec_helper'
require 'chef_zero_rspec_helper'
AWS.stub!

describe Chef::Provider::AwsRdsDbInstance do
  extend ChefZeroRspecHelper

  let(:new_resource) { 
    resource = Chef::Resource::AwsRdsDbInstance.new('new_db_instance', run_context)
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

      it 'should create new db instance' do
        new_resource.allocated_storage(100)
        new_resource.db_instance_class('db.t2.medium')
        new_resource.engine('mysql')
        new_resource.master_username('username')
        new_resource.master_user_password('pwd')
        new_resource.db_subnet_group_name('subnetgroup')

        allow_any_instance_of(AWS::RDS::DBInstanceCollection)
          .to receive(:create)
          .and_return(AWS::RDS::DBInstance.new('mydbinstance'))

        expect(new_resource).to receive(:save)
        expect(new_resource).to receive(:db_instance_id) { 'mydbinstance' }
        provider.action_create
      end

      it 'should not converge when db instance already exists' do
        existing_instance = AWS::RDS::DBInstance.new('mydbinstance')
        
        allow_any_instance_of(AWS::RDS::DBInstanceCollection)
          .to receive(:[])
          .and_return(existing_instance)
        
        allow(existing_instance)
          .to receive(:exists)
          .and_return(true)

        expect(new_resource).to_not receive(:save)
        provider.action_create
      end

    end
  end
end