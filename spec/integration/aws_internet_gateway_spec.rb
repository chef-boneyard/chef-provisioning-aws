require 'spec_helper'

describe Chef::Resource::AwsInternetGateway do
  extend AWSSupport

  when_the_chef_12_server 'exists', organization: 'foo', server_scope: :context do
    with_aws 'with a VPC' do

      aws_vpc 'test_vpc_igw_a' do
        cidr_block '10.0.0.0/24'
      end

      aws_vpc 'test_vpc_igw_b' do
        cidr_block '10.0.1.0/24'
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
              vpc test_vpc_igw_a.aws_object.id
            end
          }.to create_an_aws_internet_gateway('test_internet_gateway',
                                              vpc: test_vpc_igw_a.aws_object).and be_idempotent
        end
      end

      context 'update the attached vpc of an internet gateway' do
        it "aws_internet_gateway 'test_internet_gateway' update vpc" do
          converge {
            aws_internet_gateway 'test_internet_gateway' do
              vpc test_vpc_igw_a.aws_object.id
            end

            aws_internet_gateway 'test_internet_gateway' do
              vpc test_vpc_igw_b.aws_object.id
            end
          }

          expect(test_vpc_igw_b.aws_object.internet_gateway).not_to be_nil
        end
      end

      context 'detach an internet gateway from a vpc' do
        it "aws_internet_gateway 'test_internet_gateway' detach vpc" do
          converge {
            aws_internet_gateway 'test_internet_gateway' do
              vpc test_vpc_igw_a.aws_object.id
            end

            aws_internet_gateway 'test_internet_gateway' do
              action :detach
            end
          }

          expect(test_vpc_igw_a.aws_object.internet_gateway).to be_nil
        end
      end
    end

    with_aws 'with an Internet Gateway' do
      with_converge {
        aws_internet_gateway 'test_internet_gateway'
      }

      context 'destroy an internet gateway' do
        it "aws_internet_gateway 'test_internet_gateway'" do
          r = recipe {
            aws_internet_gateway 'test_internet_gateway' do
              action :destroy
            end
          }

          expect(r).to destroy_an_aws_internet_gateway('test_internet_gateway').and be_idempotent
        end
      end
    end
  end
end
