require 'spec_helper'

describe Chef::Resource::AwsInternetGateway do
  extend AWSSupport

  when_the_chef_12_server 'exists', organization: 'foo', server_scope: :context do
    with_aws 'with a VPC' do
      aws_vpc 'test_vpc_igw' do
        cidr_block '10.0.0.0/24'
      end

      context 'add an internet gateway' do
        it "aws_internet_gateway 'test_internet_gateway' with no parameters" do
          expect_recipe {
            aws_internet_gateway 'test_internet_gateway'
          }.to create_an_aws_internet_gateway('test_internet_gateway').and be_idempotent
        end
      end

      context 'add an internet gateway and attach a vpc' do
        it "aws_internet_gateway 'test_internet_gateway' attach vpc" do
          expect_recipe {
            aws_internet_gateway 'test_internet_gateway' do
              vpc test_vpc_igw.aws_object.id
            end
          }.to create_an_aws_internet_gateway('test_internet_gateway',
                                              vpc: test_vpc_igw.aws_object).and be_idempotent

          expect(test_vpc_igw.aws_object.internet_gateway.id).not_to be_nil
        end
      end

      context 'detach an internet gateway from a vpc' do
        it "aws_internet_gateway 'test_internet_gateway' detach vpc" do
          converge {
            aws_internet_gateway 'test_internet_gateway' do
              vpc test_vpc_igw.aws_object.id
            end

            aws_internet_gateway 'test_internet_gateway' do
              action :destroy
            end
          }

          expect(test_vpc_igw.aws_object.internet_gateway).to be_nil
        end
      end
    end
  end
end
