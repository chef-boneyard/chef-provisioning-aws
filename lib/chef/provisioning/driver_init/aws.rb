require 'chef/provisioning/aws_driver'

Chef::Provisioning.register_driver_class('aws', Chef::Provisioning::AWSDriver::Driver)
