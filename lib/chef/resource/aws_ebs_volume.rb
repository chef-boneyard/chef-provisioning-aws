require 'chef/resource/aws_resource'
require 'chef/provisioning/aws_driver'

class Chef::Resource::AwsEbsVol < Chef::Resource::AwsResource
  self.resource_name = 'aws_ebs_volume'
  self.databag_name = 'ebs_volumes'

  actions :create, :delete, :nothing
  default_action :create

  stored_attribute :volume_id
  stored_attribute :created_at

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :volume_name, :kind_of => String

  attribute :size
  attribute :mount_point
  attribute :availability_zone


  def initialize(*args)
    super
  end

  def after_created
    super
  end


end
