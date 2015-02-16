require 'spec_helper'
require 'chef_zero_rspec_helper'
AWS.stub!

describe Chef::Provider::AwsInternetGateway do
  extend ChefZeroRspecHelper
  let(:new_resource) {
    Chef::Resource::AwsInternetGateway.new('my_igw', run_context)
  }
  let(:current_resource) {
    Chef::Resource::AwsInternetGateway.new('my_igw', run_context)
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

  let(:vpc_testme) { AWS::EC2::VPC.new('vpc-testme') }
  let(:vpc_fakeme) { AWS::EC2::VPC.new('vpc-fakeme') }
  let(:igw_testme) { AWS::EC2::InternetGateway.new('igw-testme') }


  subject(:provider) {
    described_class.new(new_resource, run_context)
  }

  when_the_chef_server "is empty" do

    describe '#exists?' do
      it "is true with one igw matching name" do
        igw = AWS::EC2::InternetGateway.new('igw-testme')
        allow_any_instance_of(AWS::EC2::InternetGatewayCollection)
          .to receive(:with_tag)
          .and_return( [igw] )
        expect(subject.exists?).to be_truthy
      end

      it "is false when zero igw matching name" do
        allow_any_instance_of(AWS::EC2::InternetGatewayCollection)
          .to receive(:with_tag)
          .and_return( [] )
        expect(subject.exists?).to_not be_truthy
      end
    end

    describe '#vpc_id' do
      it 'returns id when only one matches' do
        allow_any_instance_of(AWS::EC2::VPCCollection)
          .to receive(:with_tag)
          .and_return( [vpc_testme] )
        expect(subject.vpc_id).to eql('vpc-testme')
      end

      it 'returns nil on zero matches' do
        allow_any_instance_of(AWS::EC2::VPCCollection)
          .to receive(:with_tag)
          .and_return([])
        expect(subject.vpc_id).to be_nil
      end

      it 'throws error with multiple matches' do
        new_resource.vpc 'vpc-testme'
        allow_any_instance_of(AWS::EC2::VPCCollection)
          .to receive(:with_tag)
          .and_return( [vpc_testme, vpc_fakeme] )
        expect{ subject.vpc_id }.to raise_error(ArgumentError)
      end
    end

    describe '#attached_to_vpc' do
      it 'is true when attached' do
        attachment = double(
          'attachment',
          :vpc => vpc_testme,
          :internet_gateway => igw_testme
        )
        allow_any_instance_of(AWS::EC2::InternetGateway)
          .to receive(:attachments)
          .and_return([attachment])
        expect(subject.attached_to_vpc?(vpc_testme.id))
          .to be_truthy
      end

      it 'is false when unattached' do
        allow_any_instance_of(AWS::EC2::InternetGateway)
          .to receive(:attachments)
          .and_return([])
        expect(subject.attached_to_vpc?(vpc_testme.id))
          .to_not be_truthy
      end
    end

    describe '#action_create' do
      it 'creates a new gateway' do
        allow_any_instance_of(AWS::EC2::InternetGatewayCollection)
          .to receive(:create)
          .and_return(igw_testme)
        expect(new_resource)
          .to receive(:save)
        subject.action_create
      end
    end

    describe '#action_attach' do
      it 'requires vpc attribute' do
        expect{ subject.action_attach }
          .to raise_error(
            ArgumentError,
            "my_igw needs a vpc attribute"
          )
      end

      it 'requires vpc to exist' do
        vpc_name = 'readable_vpc_name'
        new_resource.vpc vpc_name
        allow_any_instance_of(AWS::EC2::VPCCollection)
          .to receive(:with_tag)
          .with('Name',vpc_name)
          .and_return([])
        expect{ subject.action_attach }
          .to raise_error(
            ArgumentError,
            "VPC #{vpc_name} not found"
          )
      end

      it 'sends attach method' do
        new_resource.vpc 'my_vpc'
        new_resource.internet_gateway_id 'igw-testme'
        allow(provider)
          .to receive(:vpc_id)
          .and_return('vpc-testme')

        allow_any_instance_of(AWS::EC2::InternetGateway)
            .to receive(:attachments)
            .and_return([])

        expect(new_resource)
          .to receive(:save)

        subject.action_attach
      end
    end
  end
end
