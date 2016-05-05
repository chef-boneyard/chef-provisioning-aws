require 'chef/provisioning'
require 'chef/provisioning/aws_driver/driver'

require "chef/resource/aws_auto_scaling_group"
require "chef/resource/aws_cache_cluster"
require "chef/resource/aws_cache_replication_group"
require "chef/resource/aws_cache_subnet_group"
require "chef/resource/aws_cloudsearch_domain"
require "chef/resource/aws_cloudwatch_alarm"
require "chef/resource/aws_dhcp_options"
require "chef/resource/aws_ebs_volume"
require "chef/resource/aws_eip_address"
require "chef/resource/aws_elasticsearch_domain"
require "chef/resource/aws_iam_role"
require "chef/resource/aws_iam_instance_profile"
require "chef/resource/aws_image"
require "chef/resource/aws_instance"
require "chef/resource/aws_internet_gateway"
require "chef/resource/aws_key_pair"
require "chef/resource/aws_launch_configuration"
require "chef/resource/aws_load_balancer"
require "chef/resource/aws_nat_gateway"
require "chef/resource/aws_network_acl"
require "chef/resource/aws_network_interface"
require "chef/resource/aws_rds_instance"
require "chef/resource/aws_rds_subnet_group"
require "chef/resource/aws_rds_parameter_group"
require "chef/resource/aws_route_table"
require "chef/resource/aws_route53_hosted_zone"
require "chef/resource/aws_s3_bucket"
require "chef/resource/aws_security_group"
require "chef/resource/aws_server_certificate"
require "chef/resource/aws_sns_topic"
require "chef/resource/aws_sqs_queue"
require "chef/resource/aws_subnet"
require "chef/resource/aws_vpc"
require "chef/resource/aws_vpc_peering_connection"

module NoResourceCloning
  def prior_resource
    if resource_class <= Chef::Provisioning::AWSDriver::AWSResource
      Chef::Log.debug "Canceling resource cloning for #{resource_class}"
      nil
    else
      super
    end
  end
  def emit_cloned_resource_warning; end
  def emit_harmless_cloning_debug; end
end

# Chef 12.2 changed `load_prior_resource` logic to be in the Chef::ResourceBuilder class
# but that class only exists in 12.2 and up
if defined? Chef::ResourceBuilder
  # Ruby 2.0.0 has prepend as a protected method
  Chef::ResourceBuilder.send(:prepend, NoResourceCloning)
end
