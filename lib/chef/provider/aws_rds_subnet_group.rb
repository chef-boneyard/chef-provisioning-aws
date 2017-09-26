require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/provisioning/aws_driver/tagging_strategy/rds'

class Chef::Provider::AwsRdsSubnetGroup < Chef::Provisioning::AWSDriver::AWSProvider
  include Chef::Provisioning::AWSDriver::TaggingStrategy::RDSConvergeTags

  provides :aws_rds_subnet_group

  def create_aws_object
    converge_by "create RDS subnet group #{new_resource.name} in #{region}" do
      driver.create_db_subnet_group(desired_options)
    end
  end

  def destroy_aws_object(subnet_group)
    converge_by "delete RDS subnet group #{new_resource.name} in #{region}" do
      driver.delete_db_subnet_group(db_subnet_group_name: new_resource.name)
    end
  end

  def update_aws_object(subnet_group)
    updates = required_updates(subnet_group)
    if ! updates.empty?
      converge_by updates do
        driver.modify_db_subnet_group(desired_options)
      end
    end
  end

  def desired_options
    @desired_options ||= begin
      opts = {}
      opts[:db_subnet_group_name] = new_resource.name
      opts[:db_subnet_group_description] = new_resource.description
      opts[:subnet_ids] = new_resource.subnets
      AWSResource.lookup_options(opts, resource: new_resource)
    end
  end

  # Given an existing subnet group, return an array of update descriptions
  # representing the updates that need to be made.
  #
  # If no updates are needed, an empty array is returned.
  #
  def required_updates(subnet_group)
    ret = []
    if desired_options[:db_subnet_group_description] != subnet_group[:db_subnet_group_description]
      ret << "  set group description to #{desired_options[:db_subnet_group_description]}"
    end

    if ! xor_array(desired_options[:subnet_ids], subnet_ids(subnet_group[:subnets])).empty?
      ret << "  set subnets to #{desired_options[:subnet_ids]}"
    end

    if ! (desired_options[:aws_tags].nil? || desired_options[:aws_tags].empty?)
      # modify_db_subnet_group doesn't support the tags key according to
      # http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/RDS/Client.html#modify_db_subnet_group-instance_method
      Chef::Log.warn "Updating tags for RDS subnet groups is not supported."
    end

    ret.unshift("update RDS subnet group #{new_resource.name} in #{region}") unless ret.empty?
    ret
  end


  private

  def subnet_ids(subnets)
    subnets.map {|i| i[:subnet_identifier] }
  end

  def xor_array(a, b)
    (a | b) - (a & b)
  end

  # To be in line with the other resources. The aws_tags property
  # takes a hash.  But we actually need an array.
  def tag_hash_to_array(tag_hash)
    ret = []
    tag_hash.each do |key, value|
      ret << {:key => key, :value => value}
    end
    ret
  end

  def driver
    new_resource.driver.rds
  end
end
