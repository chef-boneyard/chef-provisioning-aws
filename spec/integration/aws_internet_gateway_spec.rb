require 'spec_helper'

describe Chef::Resource::AwsInternetGateway do
  extend AWSSupport

  when_the_chef_12_server 'exists', organization: 'foo', server_scope: :context do
    with_aws 'with a VPC' do

      purge_all
      aws_vpc 'test_vpc_igw_a' do
        cidr_block '10.0.0.0/24'
      end

      aws_vpc 'test_vpc_igw_b' do
        cidr_block '10.0.1.0/24'
      end

      it "creates an aws_internet_gateway with no parameters" do
        expect_recipe {
          aws_internet_gateway 'test_internet_gateway'
        }.to create_an_aws_internet_gateway('test_internet_gateway').and be_idempotent
      end

      it "creates an aws_internet_gateway and attaches it to the specified VPC" do
        expect_recipe {
          aws_internet_gateway 'test_internet_gateway' do
            vpc test_vpc_igw_a.aws_object.id
          end
        }.to create_an_aws_internet_gateway('test_internet_gateway',
          id: test_vpc_igw_a.aws_object.internet_gateways.first.id
        ).and be_idempotent
      end

      context 'with the IGW attached to an existing VPC' do
        aws_internet_gateway 'test_internet_gateway' do
          vpc test_vpc_igw_a.aws_object.id
        end

        it "updates it to the new VPC" do
          expect_recipe {
            aws_internet_gateway 'test_internet_gateway' do
              vpc test_vpc_igw_b
            end
          }.to update_an_aws_internet_gateway('test_internet_gateway',
            id: test_vpc_igw_b.aws_object.internet_gateways.first.id
          ).and be_idempotent
        end
      end

      context 'with the IGW attached to an existing VPC' do
        aws_internet_gateway 'test_internet_gateway' do
          vpc test_vpc_igw_a.aws_object.id
        end

        it "detaches it from the VPC" do
          expect_recipe {
            aws_internet_gateway 'test_internet_gateway' do
              action :detach
            end
          }.to update_an_aws_internet_gateway('test_internet_gateway',
            attachments: []
          ).and be_idempotent
        end
      end

      context 'with the IGW attached to an existing VPC' do
        aws_internet_gateway 'test_internet_gateway' do
          vpc test_vpc_igw_a.aws_object.id
        end

        it "detaches the VPC and destroys the IGW" do
          r = recipe {
            aws_internet_gateway 'test_internet_gateway' do
              action :destroy
            end
          }
          expect(r).to destroy_an_aws_internet_gateway('test_internet_gateway').and be_idempotent

          expect(test_vpc_igw_a.aws_object.internet_gateways.first).to eq(nil)
        end

        context 'with a VPC with its own managed internet gateway' do
          aws_vpc 'test_vpc_preexisting_igw' do
            cidr_block '10.0.1.0/24'
            internet_gateway true
          end

          it "deletes the old managed IGW and attaches the new one" do
            old_attached_igw = test_vpc_preexisting_igw.aws_object.internet_gateways.first.internet_gateway_id

            expect_recipe {
              aws_internet_gateway 'test_internet_gateway' do
                vpc test_vpc_preexisting_igw.aws_object.id
              end
            }.to create_an_aws_internet_gateway('test_internet_gateway',
              id: test_vpc_preexisting_igw.aws_object.internet_gateways.first.id
            ).and be_idempotent

            current_attached_igw = test_vpc_preexisting_igw.aws_object.internet_gateways.first.internet_gateway_id
            expect(current_attached_igw).not_to eq(old_attached_igw)
          end
        end

        context 'with a VPC and an attached aws_internet_gateway resource' do
          aws_internet_gateway 'test_internet_gateway'
          aws_vpc 'test_vpc_preexisting_igw' do
            cidr_block '10.0.1.0/24'
            internet_gateway test_internet_gateway
          end

          it "leaves the attachment alone if internet_gateway is set to true" do
            expect(test_vpc_preexisting_igw.aws_object.internet_gateways.first.internet_gateway_id).to eq(test_internet_gateway.aws_object.id)
            expect_recipe {
              aws_vpc 'test_vpc_preexisting_igw' do
                cidr_block '10.0.1.0/24'
                internet_gateway true
              end
            }.to match_an_aws_vpc('test_vpc_preexisting_igw',
              vpc_id: test_internet_gateway.aws_object.attachments.first.vpc_id
            ).and be_idempotent
          end

          it "deletes the attachment if internet_gateway is set to false" do
            expect_recipe {
              aws_vpc 'test_vpc_preexisting_igw' do
                cidr_block '10.0.1.0/24'
                internet_gateway false
              end
            }.to match_an_aws_internet_gateway('test_internet_gateway',
              attachments: []
            ).and be_idempotent
            expect(test_vpc_preexisting_igw.aws_object.internet_gateways.entries).to eq([])
          end
        end

        context 'with a VPC and an attached aws_internet_gateway resource' do
          aws_internet_gateway 'test_internet_gateway1'
          aws_internet_gateway 'test_internet_gateway2'
          aws_vpc 'test_vpc_preexisting_igw' do
            cidr_block '10.0.1.0/24'
            internet_gateway test_internet_gateway1
          end

          it "switches the attachment to a newly specified aws_internet_gateway" do
            expect(test_vpc_preexisting_igw.aws_object.internet_gateways.first.internet_gateway_id).to eq(test_internet_gateway1.aws_object.id)
            expect_recipe {
              aws_internet_gateway 'test_internet_gateway2' do
                vpc 'test_vpc_preexisting_igw'
              end
            }.to match_an_aws_internet_gateway('test_internet_gateway1',
              attachments: []
            ).and match_an_aws_internet_gateway('test_internet_gateway2',
              id: test_vpc_preexisting_igw.aws_object.internet_gateways.first.id
            ).and be_idempotent
          end

        end
      end
    end

  end
end
