require 'spec_helper'
require 'cheffish/rspec/chef_run_support'
require 'chef/provisioning/aws_driver/credentials'

describe 'Aws RDS DB instance' do
  extend Cheffish::RSpec::ChefRunSupport

  when_the_chef_12_server 'exists' do
    organization 'foo'

    let(:rds_client) { double(AWS::RDS::Client) }
    let!(:entry_store) { Chef::Provisioning::ChefManagedEntryStore.new }

    before :each do
      Chef::Config.chef_server_url = URI.join(Chef::Config.chef_server_url, '/organizations/foo').to_s
      allow_any_instance_of(AWS.config.class).to receive(:rds_client).and_return(rds_client)
      allow(Chef::Provisioning::ChefManagedEntryStore).to receive(:new).and_return(entry_store)
      allow_any_instance_of(Chef::Provisioning::AWSDriver::Credentials).to receive(:default)
        .and_return({
          :aws_access_key_id => 'na',
          :aws_secret_access_key => 'na'
        })
    end

    describe 'action :create' do

      before do
        resp = AWS::Core::Response.new
        resp.data[:db_instances] = [{}]
        expect(rds_client).to receive(:describe_db_instances)
          .with({:db_instance_identifier=>'my-db-instance'})
          .and_return(resp)

        resp = AWS::Core::Response.new
        resp.data = {
          :db_instance_identifier => 'my-db-instance',
          :db_instance_class => 'db.t2.small',
          :allocated_storage => 100,
          :engine => 'MySql'
        }
        expect(rds_client).to receive(:create_db_instance)
          .with({:db_instance_identifier=>'my-db-instance'})
          .and_return(resp)

        expect(entry_store).to receive(:save_data).with(
          'aws_rds_db_instance',
          'my-db-instance',
          {'reference'=>{:db_instance_identifier=>'my-db-instance'}, 'driver_url'=>'aws::us-west-2'},
          kind_of(Chef::Provisioning::ActionHandler)
        )          
      end
      
      after do
        expect(chef_run).to have_updated('aws_rds_db_instance[my-db-instance]', :create)
      end
      
      context 'simple object' do
        it 'creates the instance' do
          run_recipe do
            with_driver 'aws::us-west-2'
            aws_rds_db_instance 'my-db-instance' do
              engine 'MySql'
              db_instance_class 'db.t2.small'
              allocated_storage 100
            end
          end
        end
      end
    end  

    describe 'when supplying an existing db_instance_identifier' do
      before do
        resp = AWS::Core::Response.new
        resp.data[:db_instances] = [{
            :db_instance_identifier => 'my-db-instance',
            :db_instance_class => 'db.t2.small',
            :allocated_storage => 100,
            :engine => 'MySql'          
        }]
        expect(rds_client).to receive(:describe_db_instances)
          .with({:db_instance_identifier=>'my-db-instance'})
          .and_return(resp)
      end

      it 'finds the db instance without updating it' do
        run_recipe do
          with_driver 'aws::us-west-2'
          aws_rds_db_instance 'my-db-instance' do
            engine 'MySql'
            db_instance_class 'db.t2.small'
            allocated_storage 100
          end
        end
      end
    end
  end
end