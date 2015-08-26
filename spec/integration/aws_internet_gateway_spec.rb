require 'spec_helper'

describe Chef::Resource::AwsInternetGateway do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "with a VPC and an internet gateway" do
      vpc = nil
      internet_gateway = nil

      before {
        vpc = driver.ec2.vpcs.create('10.0.0.0/24')
      }

      it "aws_internet_gateway 'test_internet_gateway' with no parameters" do
        expect_recipe {
          aws_internet_gateway 'test_internet_gateway'
        }.to create_an_aws_internet_gateway('test_internet_gateway').and be_idempotent
      end

      it "aws_internet_gateway 'test_internet_gateway' with attached vpc" do
        expect_recipe {
          aws_internet_gateway 'test_internet_gateway' do
            vpc vpc.id
          end
        }.to create_an_aws_internet_gateway('test_internet_gateway').and be_idempotent
        filters = [
          {:name => 'attachment.vpc-id', :values => [vpc.id]}
        ]
        desc_internet_gws = driver.ec2.client.describe_internet_gateways(:filters => filters)[:internet_gateway_set]
        internet_gateway = driver.ec2.internet_gateways[desc_internet_gws.first[:internet_gateway_id]]
        expect(desc_internet_gws).not_to be_empty
      end

      after {
        if internet_gateway && internet_gateway.exists? && !internet_gateway.vpc.nil?
          internet_gateway.detach(vpc.id)
        end

        if vpc && vpc.exists?
          vpc.delete
        end
      }
    end
  end
end
