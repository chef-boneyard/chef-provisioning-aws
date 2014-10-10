require 'chef/provider/lwrp_base'
require 'chef_metal_aws/credentials'

class Chef::Provider::AwsProvider < Chef::Provider::LWRPBase
  use_inline_resources

  attr_reader :credentials

  # All these need to implement whyrun
  def whyrun_supported?
    true
  end

  def from_hash hash
    hash.each do |k,v|
      begin
        self.instance_variable_set("@#{k}", v)
      rescue NameError => ne
        # nothing...
      end
    end
    self
  end

  def resource_from_databag(fqn, chef_server = Cheffish.default_chef_server)
    chef_api = Cheffish.chef_server_api(chef_server)
    begin
      data = chef_api.get("/data/#{databag_name}/#{fqn}")
     rescue Net::HTTPServerException => e
      if e.response.code == '404'
        nil
      else
        raise
      end
    end
  end

  def initialize(*args)
    super
    # TODO - temporary, needs to be better
    @credentials = ChefMetalAWS::Credentials.new
    @credentials.load_default
    credentials = @credentials.default
    AWS.config(:access_key_id => credentials[:aws_access_key_id],
               :secret_access_key => credentials[:aws_secret_access_key])
  end

  def self.databag_name
    raise 'Class does not implement databag name'
  end

  def fqn
    if id
      id
    else
      "#{new_resource.name}_#{new_resource.region_name}"
    end
  end

  # AWS objects we might need - TODO: clean this up
  def ec2
    credentials = @credentials.default
    region = new_resource.region_name || credentials[:region]
    # Pivot region
    AWS.config(:region => region)
    @ec2 ||= AWS::EC2.new
  end

  def sns
    credentials = @credentials.default
    region = new_resource.region_name || credentials[:region]
    # Pivot region
    AWS.config(:region => region)
    @sns ||= AWS::SNS.new
  end

  def sqs
    credentials = @credentials.default
    region = new_resource.region_name || credentials[:region]
    # Pivot region
    AWS.config(:region => region)
    @sqs ||= AWS::SQS.new
  end

  def s3
    credentials = @credentials.default
    region = new_resource.region_name || credentials[:region]
    # Pivot region
    AWS.config(:region => region)
    @s3 ||= AWS::S3.new
  end

end