require 'chef/provisioning/aws_driver/driver'

Chef::Provisioning.register_driver_class('aws', Chef::Provisioning::AWSDriver::Driver)
