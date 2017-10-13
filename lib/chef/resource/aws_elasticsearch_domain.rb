require 'chef/provisioning/aws_driver/aws_resource'

module AWS
  class Elasticsearch
    class Domain
    end
  end
end

class Chef::Resource::AwsElasticsearchDomain < Chef::Provisioning::AWSDriver::AWSResource
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type ::Aws::CloudSearchDomain

  attribute :domain_name, kind_of: String, name_attribute: true

  # Cluster Config
  attribute :instance_type, kind_of: String
  attribute :instance_count, kind_of: Integer
  attribute :dedicated_master_enabled, kind_of: [TrueClass, FalseClass]
  attribute :dedicated_master_type, kind_of: String
  attribute :dedicated_master_count, kind_of: Integer
  attribute :zone_awareness_enabled, kind_of: [TrueClass, FalseClass]

  # EBS Options
  attribute :ebs_enabled, kind_of: [TrueClass, FalseClass]
  attribute :volume_type, equal_to: ["standard", "gp2", "io1"]
  attribute :volume_size, kind_of: Integer
  attribute :iops, kind_of: Integer

  # Snapshot Options
  attribute :automated_snapshot_start_hour, kind_of: Integer

  # Access Policies
  attribute :access_policies, kind_of: String

  def aws_object
    driver.elasticsearch_client
      .describe_elasticsearch_domains(domain_names: [domain_name])[:domain_status_list]
      .find { |d| !d[:deleted] }
  end
end
