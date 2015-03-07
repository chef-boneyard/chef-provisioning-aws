require 'spec_helper'
require 'chef_zero_rspec_helper'
AWS.stub!

describe Chef::Provider::AwsRdsOptionGroup do
  extend ChefZeroRspecHelper

  let(:new_resource) { 
    resource = Chef::Resource::AwsRdsOptionGroup.new('new-option-group', run_context)
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
        new_resource.engine_name('mysql')
        new_resource.major_engine_version('5.6')
        expect { provider.action_create }
          .to raise_error(
            RuntimeError, "Can't create an option group without a description"
          )
      end

      it 'requires an engine name' do
        new_resource.description('some_description')
        new_resource.major_engine_version('5')
        expect { provider.action_create }
          .to raise_error(
            RuntimeError, "Can't create an option group without an engine name"
          )
      end

      it 'requires a major engine version' do
        new_resource.description('some_description')
        new_resource.engine_name('mysql')
        expect { provider.action_create }
          .to raise_error(
            RuntimeError, "Can't create an option group without a major engine version"
          )
      end

      it 'should create the option group' do
        new_resource.description('some_description')
        new_resource.engine_name('mysql')
        new_resource.major_engine_version('5.6')
        expect(new_resource).to receive(:save)
        provider.action_create
      end

      it 'should not converge when the option group already exists' do
        new_resource.description('some_description')
        new_resource.engine_name('mysql')
        new_resource.major_engine_version('5.6')
        allow_any_instance_of(AWS::RDS::Client::V20140901)
          .to receive(:describe_option_groups)
          .and_return({:data => { :option_groups_list => [{}] }})

        expect(new_resource).to_not receive(:save)
        provider.action_create
      end
    end
  end
end