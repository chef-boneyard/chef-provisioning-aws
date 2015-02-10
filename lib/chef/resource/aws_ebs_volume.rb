require 'chef/resource/aws_resource'
require 'chef/provisioning/aws_driver'

class Chef::Resource::AwsEbsVolume < Chef::Resource::AwsResource
  self.resource_name = 'aws_ebs_volume'
  self.databag_name = 'ebs_volumes'

  actions :create, :delete, :attach, :detach, :nothing
  default_action :create

  stored_attribute :volume_id
  stored_attribute :created_at
  stored_attribute :attached_to_instance
  stored_attribute :attached_to_device

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :size, :kind_of => Integer
  attribute :snapshot_id, :kind_of => String, :default => ''
  attribute :availability_zone, :kind_of => String
  attribute :volume_type, :kind_of => Symbol, :equal_to => [:gp2, :io1, :standard], :default => :gp2
  attribute :iops, :kind_of => Integer
  attribute :encrypted, :kind_of => [TrueClass, FalseClass], :default => false
  attribute :instance_id, :kind_of => String
  attribute :device, :kind_of => String
end
