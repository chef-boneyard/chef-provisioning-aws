require 'chef/provisioning/aws_driver/aws_resource'

module AWS
  class CloudSearch
    class Domain
      # The version of the AWS sdk we are using doesn't have a model
      # object for CloudSearch Domains. This empty class is here to
      # make the reset of chef-provisioning happy.
    end
  end
end

class Chef::Resource::AwsCloudsearchDomain < Chef::Provisioning::AWSDriver::AWSResource
  aws_sdk_type ::Aws::CloudSearchDomain
  attribute :name, kind_of: String, name_attribute: true
  attribute :cloudsearch_api_version, equal_to: ["20130101", "20110201"], default: "20130101"

  # Availability Options
  attribute :multi_az, kind_of: [TrueClass, FalseClass], default: false

  # Scaling Parameters
  attribute :instance_type, equal_to: ["search.m1.small", "search.m3.medium",
                                       "search.m3.large", "search.m3.xlarge",
                                       "search.m3.2xlarge"]
  attribute :partition_count, kind_of: Integer
  attribute :replication_count, kind_of: Integer

  # Service Access Policies
  # TODO(ssd): We need to decide how we want to model access policies
  # For now we just allow the user to shove the policy in via a string.
  attribute :access_policies, kind_of: String


  # Indexing Options
  # TODO(ssd): Like Access Polcies, we should decide
  # whether we want a DSL for defining index fields, or just allow the
  # user to pass in an array properly formated hash.
  attribute :index_fields, kind_of: Array

  # None of the cloudsearch objects actually have instance-specific
  # objects in the version of the AWS API we are using.  This will
  # return a hash with some relevant information about the domain.
  def aws_object
    driver.cloudsearch.describe_domains(domain_names: [name])[:domain_status_list].find {|d| !d[:deleted] }
  end

  def cloudsearch_api_version(arg=nil)
    unless arg.nil?
      Chef::Log.warn("The ':cloudsearch_api_version' has been deprecated since it has been removed in AWS SDK version 2.")
    end
  end
end
