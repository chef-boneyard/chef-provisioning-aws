require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/provisioning/aws_driver/tagging_strategy/ec2'

class Chef::Provider::AwsInstance < Chef::Provisioning::AWSDriver::AWSProvider
  include Chef::Provisioning::AWSDriver::TaggingStrategy::EC2ConvergeTags

  provides :aws_instance

  def create_aws_object(instance); end

  def update_aws_object(instance); end

  def destroy_aws_object(instance)
    message = "delete instance #{new_resource}"
    message += " in VPC #{instance.vpc.id}" unless instance.vpc.nil?
    message += " in #{region}"
    converge_by message do
      instance.terminate
    end
    converge_by "waited until instance #{new_resource} is :terminated" do
      # When purging, we must wait until the instance is fully terminated - thats the only way
      # to delete the network interface that I can see
      instance.wait_until_terminated do |w|
        # TODO look at `wait_for_status` - delay and max_attempts should be configurable
        w.delay = 5
        w.max_attempts = 60
        w.before_wait do |attempts, response|
          action_handler.report_progress "waited #{(attempts-1)*5}/#{60*5}s for #{instance.id} status to terminate..."
        end
      end
    end
  end
end
