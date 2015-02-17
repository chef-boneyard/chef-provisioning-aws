require 'chef/provider/aws_provider'

class Chef::Provider::AwsInternetGateway < Chef::Provider::AwsProvider
  action :create do
    unless self.exists?
      converge_by(
        "Creating new Internet Gateway #{name} in #{new_resource.region_name}",
      ) do
        igw = ec2.internet_gateways.create
        igw.tags['Name'] = new_resource.name
        new_resource.internet_gateway_id igw.id
        new_resource.save
      end
    end
  end

  action :attach do
    raise ArgumentError, "#{name} needs a vpc attribute" unless vpc_name
    raise ArgumentError, "VPC #{vpc_name} not found" unless vpc_id
    unless attached_to_vpc?(vpc_id)
      converge_by(
        "Attaching Internet Gateway #{name} (#{id}) to VPC {vpc_name} (#{vpc_id}) in #{new_resource.region_name}",
      ) do
        ec2.internet_gateways[id].attach(vpc_id)
        new_resource.save
      end
    end
  end

  action :delete do
    # will need :detach in order to delete
    #    aws ec2 detach-internet-gateway --internet-gateway-id igw-1528ff70 --vpc-id vpc-4d4be328
    # {
    #    "return": "true"
    # }
  end

  def exists?
    igc = ec2.internet_gateways
          .with_tag('Name', new_resource.name)
    igc.count == 1
  rescue
    false
  end

  def vpc_id
    @vpc_id ||= begin
      vpcs = ec2.vpcs.with_tag('Name', vpc_name)
      if vpcs.count > 1
        raise \
          ArgumentError, "VPC name #{vpc_name} matches #{vpcs.count} VPCs"
      elsif vpcs.count == 1
        vpcs.first.id
      end
    end
  end

  def vpc_name
    new_resource.vpc
  end

  def name
    new_resource.name
  end

  def internet_gateway_id
    new_resource.internet_gateway_id
  end

  alias_method :id, :internet_gateway_id

  def attached_to_vpc?(vpc_id)
    ec2.internet_gateways[internet_gateway_id]
      .attachments.any? { |a| a.vpc.id == vpc_id }
  rescue NoMethodError,      AWS::Core::Resource::NotFound
    false
  end
end
