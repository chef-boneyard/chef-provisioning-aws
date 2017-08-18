require 'chef/provisioning/aws_driver/aws_provider'
require 'retryable'

class Chef::Provider::AwsInternetGateway < Chef::Provisioning::AWSDriver::AWSProvider
  include Chef::Provisioning::AWSDriver::TaggingStrategy::EC2ConvergeTags

  provides :aws_internet_gateway

  def action_detach
    internet_gateway = Chef::Resource::AwsInternetGateway.get_aws_object(new_resource.name, resource: new_resource)
    detach_vpc(internet_gateway)
  end

  protected

  def create_aws_object
    desired_vpc = Chef::Resource::AwsVpc.get_aws_object(new_resource.vpc, resource: new_resource) if new_resource.vpc

    converge_by "create internet gateway #{new_resource.name} in region #{region}" do
      ec2_resource = ::Aws::EC2::Resource.new(new_resource.driver.ec2)
      internet_gateway = ec2_resource.create_internet_gateway
      retry_with_backoff(::Aws::EC2::Errors::InvalidInternetGatewayIDNotFound) do
        internet_gateway.create_tags({tags: [{key: "Name", value: new_resource.name}]})
      end

      if desired_vpc
        attach_vpc(desired_vpc, internet_gateway)
      end

      internet_gateway
    end
  end

  def update_aws_object(internet_gateway)
    ec2_resource = new_resource.driver.ec2.describe_internet_gateways(:internet_gateway_ids=>[internet_gateway.id])
    current_vpc = ec2_resource.internet_gateways.first.attachments.first

    if new_resource.vpc
      desired_vpc = Chef::Resource::AwsVpc.get_aws_object(new_resource.vpc, resource: new_resource)
      current_vpc_id = current_vpc.vpc_id unless current_vpc.nil?
      desired_vpc_id = desired_vpc.vpc_id unless desired_vpc.nil?
      if current_vpc_id != desired_vpc_id
        detach_vpc(internet_gateway)
        attach_vpc(desired_vpc, internet_gateway)
      end
    end
  end

  def destroy_aws_object(internet_gateway)
    converge_by "delete internet gateway #{new_resource.name} in region #{region}" do
      detach_vpc(internet_gateway)
      internet_gateway.delete
    end
  end

  private

  def attach_vpc(vpc, desired_gateway)
    if vpc.internet_gateways.first && vpc.internet_gateways.first != desired_gateway
      current_driver = self.new_resource.driver
      current_chef_server = self.new_resource.chef_server
      Cheffish.inline_resource(self, action) do
        aws_vpc vpc.id do
          cidr_block vpc.cidr_block
          internet_gateway false
          driver current_driver
          chef_server current_chef_server
        end
      end
    end
    converge_by "attach vpc #{vpc.id} to #{desired_gateway.id}" do
      desired_gateway.attach_to_vpc(vpc_id: vpc.id)
    end
  end

  def detach_vpc(internet_gateway)
    ec2_resource = new_resource.driver.ec2.describe_internet_gateways(:internet_gateway_ids=>[internet_gateway.id])
    vpcid = ec2_resource.internet_gateways.first.attachments.first
    vpc_id = vpcid.vpc_id unless vpcid.nil?
    if vpc_id
      converge_by "detach vpc #{vpc_id} from internet gateway #{internet_gateway.id}" do
        internet_gateway.detach_from_vpc(vpc_id: vpc_id)
      end
    end
  end

end
