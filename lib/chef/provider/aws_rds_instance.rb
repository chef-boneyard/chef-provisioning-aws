require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/provisioning/aws_driver/tagging_strategy/rds'

class Chef::Provider::AwsRdsInstance < Chef::Provisioning::AWSDriver::AWSProvider
  include Chef::Provisioning::AWSDriver::TaggingStrategy::RDSConvergeTags

  provides :aws_rds_instance

  REQUIRED_OPTIONS = %i(db_instance_identifier allocated_storage engine
                        db_instance_class master_username master_user_password)

  OTHER_OPTIONS = %i(db_snapshot_identifier engine_version multi_az iops publicly_accessible db_name port db_subnet_group_name db_parameter_group_name)

  def update_aws_object(instance)
    Chef::Log.warn("aws_rds_instance does not support modifying a started instance")
    # There are required optiosn (like `allocated_storage`) that the use may not
    # specify on a resource to perform an update.  For example, they may want to
    # only specify iops to modify that attribute on an update after initial
    # creation.  In this case we need to load the required options from the existing
    # aws_object and only override it if the user has specified a value in the
    # resource.  Ideally, it would be nice to mark values as required on the
    # resource but right now there is not a `required_on_create`.  This would
    # also be different if chef-provisioning performed resource cloning, which
    # it does not.
  end

  def create_aws_object
    converge_by "create RDS instance #{new_resource.db_instance_identifier} in #{region}" do
      if new_resource.db_snapshot_identifier
        snap_options_hash = [:allocated_storage, :master_username, :master_user_password, :engine_version].each { |k| options_hash.delete(k) }
        new_resource.driver.rds_client.restore_db_instance_from_db_snapshot(options_hash).db_instance
      else
        new_resource.driver.rds_resource.create_db_instance(options_hash)
      end
    end
  end

  def destroy_aws_object(instance)
    converge_by "delete RDS instance #{new_resource.db_instance_identifier} in #{region}" do
      instance.delete(skip_final_snapshot: true)
    end
    # Wait up to 10 minutes for the db instance to shutdown
    converge_by "waited until RDS instance #{new_resource.name} was deleted" do
      wait_for(
        aws_object: instance,
        # http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.DBInstance.Status.html
        # It cannot _actually_ return a deleted status, we're just looking for the error
        query_method: :db_instance_status,
        expected_responses: ['deleted'],
        acceptable_errors: [::Aws::RDS::Errors::DBInstanceNotFound],
        tries: 60,
        sleep: 10
      ) { |instance| instance.reload }
    end
  end

  # Sets the additional options then overrides it with all required options from
  # the resource as well as optional options
  def options_hash
    @options_hash ||= begin
      opts = Hash[new_resource.additional_options.map{|(k,v)| [k.to_sym,v]}]
      REQUIRED_OPTIONS.each do |opt|
        opts[opt] = new_resource.send(opt)
      end
      OTHER_OPTIONS.each do |opt|
        opts[opt] = new_resource.send(opt) if ! new_resource.send(opt).nil?
      end
      AWSResource.lookup_options(opts, resource: new_resource)
      opts
    end
  end

end
