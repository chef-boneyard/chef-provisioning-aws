require 'chef/provisioning/aws_driver/aws_provider'
require 'retryable'

class Chef::Provider::AwsInternetGateway < Chef::Provisioning::AWSDriver::AWSProvider

  protected

  def create_aws_object
    self.vpc = Chef::Resource::AwsVpc.get_aws_object(new_resource.vpc, resource: new_resource) if new_resource.vpc

    converge_by "create internet gateway #{new_resource.name} in region #{region}" do
      internet_gateway = new_resource.driver.ec2.internet_gateways.create
      retry_with_backoff(AWS::EC2::Errors::InvalidInternetGatewayID::NotFound) do
        internet_gateway.tags['Name'] = new_resource.name
      end

      if vpc
        attach_vpc(vpc, internet_gateway)
      end

      internet_gateway
    end
  end

  def update_aws_object(internet_gateway)
    self.vpc = internet_gateway.vpc

    if new_resource.vpc
      desired_vpc = Chef::Resource::AwsVpc.get_aws_object(new_resource.vpc, resource: new_resource)
      if vpc != desired_vpc
        attach_vpc(desired_vpc, internet_gateway)
      end
    end
  end

  def destroy_aws_object(internet_gateway)
    converge_by "delete internet gateway #{new_resource.name} in region #{region}" do
      begin
        detach_vpc(internet_gateway)
        internet_gateway.delete
      rescue AWS::EC2::Errors::InvalidInternetGatewayID::NotFound
        raise "internet gateway #{internet_gateway.id} not found"
      end
    end
  end

  private

  attr_accessor :vpc

  def attach_vpc(vpc, internet_gateway)
    action_handler.perform_action "attach vpc #{vpc.id} to #{internet_gateway.id}" do
      internet_gateway.vpc = vpc
    end
  end

  def detach_vpc(internet_gateway)
    action_handler.perform_action "detach any currently attached vpc from internet gateway #{internet_gateway.id}" do
      internet_gateway.detach(internet_gateway.vpc) if internet_gateway.vpc
    end
  end

end
