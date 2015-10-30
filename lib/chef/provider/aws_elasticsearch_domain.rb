require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/provisioning/aws_driver/tagging_strategy/elasticsearch'

class Chef::Provider::AwsElasticsearchDomain < Chef::Provisioning::AWSDriver::AWSProvider
  provides :aws_elasticsearch_domain

  def create_aws_object
    converge_by "create Elasticsearch domain #{new_resource.domain_name}" do
      es_client.create_elasticsearch_domain(update_payload)
    end
  end

  def destroy_aws_object(domain)
    converge_by "destroy Elasticsearch domain #{new_resource.domain_name}" do
      es_client.delete_elasticsearch_domain({domain_name: new_resource.domain_name})
    end
  end

  def update_aws_object(domain)
    updates = required_updates(domain)
    if ! updates.empty?
      converge_by updates do
        es_client.update_elasticsearch_domain_config(update_payload)
      end
    end
  end

  def aws_tagger
    @aws_tagger ||= begin
                      strategy = Chef::Provisioning::AWSDriver::TaggingStrategy::Elasticsearch.new(
                        es_client,
                        new_resource.aws_object.arn,
                        new_resource.aws_tags)
                      Chef::Provisioning::AWSDriver::AWSTagger.new(strategy, action_handler)
                    end
  end

  def converge_tags
    aws_tagger.converge_tags
  end

  private

  def required_updates(object)
    ret = []
    ret << "   update cluster configuration" if cluster_options_changed?(object)
    ret << "   update ebs options" if ebs_options_changed?(object)
    ret << "   update snapshot options" if snapshot_options_changed?(object)
    ret << "   update access policy" if access_policy_changed?(object)
    ret.unshift("update Elasticsearch domain #{new_resource.name}") unless ret.empty?
    ret
  end

  def update_payload
    payload = {domain_name: new_resource.domain_name}
    payload.merge!(ebs_options) if ebs_options_present?
    payload.merge!(cluster_options) if cluster_options_present?
    payload.merge!(snapshot_options) if snapshot_options_present?
    payload[:access_policies] = new_resource.access_policies if new_resource.access_policies
    payload
  end

  EBS_OPTIONS = %i(ebs_enabled volume_type volume_size iops)
  def ebs_options
    opts = EBS_OPTIONS.inject({}) do |accum, i|
      new_resource.send(i).nil? ? accum : accum.merge({i => new_resource.send(i)})
    end
    {ebs_options: opts}
  end

  def ebs_options_present?
    EBS_OPTIONS.any? {|i| !new_resource.send(i).nil? }
  end

  def ebs_options_changed?(object)
    changed?(ebs_options[:ebs_options], object.ebs_options)
  end

  CLUSTER_OPTIONS = %i(instance_type instance_count dedicated_master_enabled
                       dedicated_master_type dedicated_master_count zone_awareness_enabled)

  def cluster_options
    opts = CLUSTER_OPTIONS.inject({}) do |accum, i|
      new_resource.send(i).nil? ? accum : accum.merge({i => new_resource.send(i)})
    end
    {elasticsearch_cluster_config: opts}
  end

  def cluster_options_present?
    CLUSTER_OPTIONS.any? {|i| !new_resource.send(i).nil? }
  end

  def cluster_options_changed?(object)
    changed?(cluster_options[:elasticsearch_cluster_config], object.elasticsearch_cluster_config)
  end

  def snapshot_options
    if !new_resource.automated_snapshot_start_hour.nil?
      {snapshot_options: { automated_snapshot_start_hour: new_resource.automated_snapshot_start_hour }}
    else
      {}
    end
  end

  def snapshot_options_present?
    ! new_resource.automated_snapshot_start_hour.nil?
  end

  def snapshot_options_changed?(object)
    changed?(snapshot_options[:snapshot_options] || {}, object.snapshot_options)
  end

  def access_policy_changed?(object)
    if new_resource.access_policies
      Chef::JSONCompat.parse(object.access_policies) != Chef::JSONCompat.parse(new_resource.access_policies)
    else
      false
    end
  end

  def changed?(desired, actual)
    desired.each do |key, value|
      return true if actual[key] != value
    end
    false
  end

  def es_client
    @es_client ||= new_resource.driver.elasticsearch_client
  end
end
