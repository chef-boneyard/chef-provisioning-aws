require 'chef/provisioning/aws_driver/aws_provider'
require 'retryable'

class Chef::Provider::AwsInternetGateway < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_internet_gateway

  def action_detach
    internet_gateway = Chef::Resource::AwsInternetGateway.get_aws_object(new_resource.name, resource: new_resource)
    detach_vpc(internet_gateway)
  end

  protected

  def create_aws_object
    desired_vpc = Chef::Resource::AwsVpc.get_aws_object(new_resource.vpc, resource: new_resource) if new_resource.vpc

    converge_by "create internet gateway #{new_resource.name} in region #{region}" do
      internet_gateway = new_resource.driver.ec2.internet_gateways.create
      retry_with_backoff(AWS::EC2::Errors::InvalidInternetGatewayID::NotFound) do
        internet_gateway.tags['Name'] = new_resource.name
      end

      if desired_vpc
        attach_vpc(desired_vpc, internet_gateway)
      end

      internet_gateway
    end
  end

  def update_aws_object(internet_gateway)
    current_vpc = internet_gateway.vpc

    if new_resource.vpc
      desired_vpc = Chef::Resource::AwsVpc.get_aws_object(new_resource.vpc, resource: new_resource)
      if current_vpc != desired_vpc
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

  attr_accessor :vpc

  def attach_vpc(vpc, internet_gateway)
    converge_by "attach vpc #{vpc.id} to #{internet_gateway.id}" do
      internet_gateway.vpc = vpc
    end
  end

  def detach_vpc(internet_gateway)
    if internet_gateway.vpc
      converge_by "detach vpc #{internet_gateway.vpc.id} from internet gateway #{internet_gateway.id}" do
        internet_gateway.detach(internet_gateway.vpc)
      end
    end
  end

end
