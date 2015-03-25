require 'chef/provisioning/aws_driver'

with_driver 'aws::eu-west-1'

test_vpc = aws_vpc 'test-vpc' do
  cidr_block '10.0.0.0/24'
end

# resource name
aws_security_group 'test-sg-1' do
  vpc 'test-vpc'
end

# aws object id (String)
# If you know this ahead of time, don't need the lazy block
aws_security_group 'test-sg-2' do
  vpc lazy { test_vpc.aws_object.id }
end

# aws object
# The lazy block is required - first time through, aws_object isn't
# created at compile time
aws_security_group 'test-sg-3' do
  vpc lazy { test_vpc.aws_object }
end

# resource
aws_security_group 'test-sg-4' do
  vpc test_vpc
end

(1..4).each do |i|
  aws_security_group "test-sg-#{i}" do
    action :destroy
  end
end

aws_vpc 'test-vpc' do
  action :destroy
end
