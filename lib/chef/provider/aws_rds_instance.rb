require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/provisioning/aws_driver/tagging_strategy/rds'

class Chef::Provider::AwsRdsInstance < Chef::Provisioning::AWSDriver::AWSProvider
  include Chef::Provisioning::AWSDriver::TaggingStrategy::RDSConvergeTags

  provides :aws_rds_instance

  ## any new first class attributes that should be passed to rds should be added here.  these are used to assemble options_hash
  REQUIRED_OPTIONS = %i(db_instance_identifier allocated_storage engine
                        db_instance_class master_username master_user_password)

  OTHER_OPTIONS = %i(engine_version multi_az iops publicly_accessible db_name port db_subnet_group_name db_parameter_group_name)


## update (and therefor modify) will ALWAYS called on any run after a create
## there's no sane ability to compare desired state vs current state without extensive per-option logic
## calling modify (even with/without apply_immediately) is safe - it only
## "updates" the master password (modify has know way to determine the previous
## one, of course), which is effectively a non-op.
  def update_aws_object(instance)

    # TODO
    ### these options need to be transformed...this could get hairy?
    ### create and modify use different names for them.
    ### and re-naming an instance could definitely get weird.
    # db_instance_identifier - create
    # new_db_instance_identifier - modify
    # port - create
    # db_port_number - modify

    ## remove create specific options we can't pass to modify
    [:engine, :master_username, :db_subnet_group_name, :availability_zone, :character_set_name, :db_cluster_identifier, :db_name, :kms_key_id, :storage_encrypted, :tags, :timezone].each do |key|
      options_hash.delete(key)
    end

    ## always wait for a safe state (available) before we try to apply a modification.
    wait_for(
      aws_object: instance,
      query_method: :db_instance_status,
      expected_responses: ['available'],
      tries: new_resource.wait_tries,
      sleep: new_resource.wait_time
    ) { |instance|
      instance.reload
      Chef::Log.info "Update RDS instance: before update, waiting for #{new_resource.db_instance_identifier} to be available.  State: #{instance.db_instance_status} - pending: #{instance.pending_modified_values.to_h}" if instance.db_instance_status != "available"
    }

    updated={} #so we can use this outside the converge_by
    converge_by "update RDS instance #{new_resource.db_instance_identifier} in #{region}" do
      updated=new_resource.driver.rds_client.modify_db_instance(options_hash).to_h[:db_instance]
    end

    if new_resource.wait_for_update
      slept=false
      ## use the response from modify to determine if we applied an update we should wait for
      updated[:pending_modified_values].each do |k, v|
        ## we ALWAYS apply an update, but we dont need to "wait" for the master_user_password (or do we?)
        if k.to_s != "master_user_password"
          if ! slept  #maybe we should just break the loop?
            Chef::Log.info "Updated RDS instance: #{new_resource.db_instance_identifier}, sleeping #{new_resource.wait_time} seconds to verify state is now available due to #{updated[:pending_modified_values]}"
            sleep new_resource.wait_time  #it takes a few seconds before the instance goes out of 'available'
            slept=true
          end
          converge_by "waiting until RDS instance is available after update  #{new_resource.db_instance_identifier} in #{region}" do
            wait_for(
              aws_object: instance,
              query_method: :db_instance_status,
              expected_responses: ['available'],
              tries: new_resource.wait_tries,
              sleep: new_resource.wait_time
            ) { |instance|
              instance.reload
              Chef::Log.info "Update RDS instance, waiting for #{new_resource.db_instance_identifier} to be available. State: #{instance.db_instance_status} - pending: #{instance.pending_modified_values.to_h}"
            }
          end
        end
      end
    end

  end #def update

  def create_aws_object

    ## remove modify specific options we can't pass to create
    [:apply_immediately, :allow_major_version_upgrade, :ca_certificate_identifier ].each do |key|
      options_hash.delete(key)
    end

    Chef::Log.info "Create RDS instance: #{new_resource.db_instance_identifier}"
    instance={}
    converge_by "create RDS instance #{new_resource.db_instance_identifier} in #{region}" do
      instance=new_resource.driver.rds_resource.create_db_instance(options_hash)
    end

    if new_resource.wait_for_create
      converge_by "waiting until RDS instance is available after create  #{new_resource.db_instance_identifier} in #{region}" do
        ## custom wait loop - we can't use wait_for because we want to check for multiple possibilities, and some of them are undef at the time we start the loop.
        ## wait for:
        ##   endpoint address to be available - at this point, the instance is typically usable. we get access to the instance a good 1000+s earlier than we would waiting for available.
        ##   available or backing-up states, just in case we can't/dont get an endpoint address for some reason.
        #just in case - sometimes instance is still nil when we get here, so avoid error cases
        tries = 10
        while instance.nil?
          sleep 10
          tries -= 1
          raise "timed out waiting for #{new_resource.db_instance_identifier} instance object to become non-nil, something failed" if tries < 0
        end
        tries = new_resource.wait_tries
        while defined?(instance.endpoint).nil? \
         or defined?(instance.endpoint.address).nil? \
         or instance.db_instance_status == 'available' \
         or instance.db_instance_status == 'backing-up'
          instance.reload  #reload first so we get a useful final log
          Chef::Log.info "Create RDS instance: waiting for #{new_resource.db_instance_identifier} to be available.  State: #{instance.db_instance_status}, pending modifications: #{instance.pending_modified_values.to_h}, endpoint: #{instance.endpoint.to_h if ! instance.endpoint.nil? }"
          sleep new_resource.wait_time
          tries -= 1
          raise StatusTimeoutError.new(instance, instance.db_instance_status, "endpoint available, 'available', or 'backing-up'") if tries < 0
        end
        Chef::Log.info "Create RDS instance:  #{new_resource.db_instance_identifier} endpoint address = #{instance.endpoint.address}:#{instance.endpoint.port}"
      end
    end # end wait?
  end #def create

  def destroy_aws_object(instance)

    ### No need to wait before destroy - destroy doesnt require an available/etc state.
    converge_by "delete RDS instance #{new_resource.db_instance_identifier} in #{region}" do
      instance.delete(skip_final_snapshot: new_resource.skip_final_snapshot)
    end
    if new_resource.wait_for_delete
      # Wait up to sleep * tries / 60 minutes for the db instance to shutdown
      converge_by "waited until RDS instance #{new_resource.name} was deleted" do
        wait_for(
          aws_object: instance,
          # http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.DBInstance.Status.html
          # It cannot _actually_ return a deletsed status, we're just looking for the error
          query_method: :db_instance_status,
          expected_responses: ['deleted'],
          acceptable_errors: [::Aws::RDS::Errors::DBInstanceNotFound],
          tries: new_resource.wait_tries,
          sleep: new_resource.wait_time
        ) { |instance|
            instance.reload
            Chef::Log.info "Delete RDS instance: waiting for #{new_resource.db_instance_identifier} to be deleted.  State: #{instance.db_instance_status}"
       }
      end
    end
  end #def destroy

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

