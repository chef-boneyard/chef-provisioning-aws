require 'chef/provisioning/aws_driver'

with_driver 'aws::us-west-2'

aws_key = aws_key_pair 'ref-key-pair-ebs'

ref_machine = machine 'ref-machine-1'

# use resource to create aws volume
ref_volume = aws_ebs_volume 'ref-volume-ebs' do
  action :create
  availability_zone 'us-west-2a'
  size 1
end

ruby_block 'set instance id attr and delete instance node data' do
  block do
     ref_node = search(:node, "name:#{ref_machine.name}").first
     node.default['instance_id'] = ref_node['chef_provisioning']['reference']['instance_id']
     ref_machine_node = Chef::Node.new
     ref_machine_node.name(ref_machine.name)
     ref_machine_node.destroy
  end
end

# verify instance id string format
aws_ebs_volume ref_volume.name do
  action [:attach, :detach]
  machine lazy { node.default['instance_id'] }
  device '/dev/xvdf'
end

# verify aws::ec2::instance
aws_ebs_volume ref_volume.name do
  action [:attach, :detach]
  machine lazy { AWS::EC2::Instance.new(node.default['instance_id']) }
  device '/dev/xvdf'
end

# TODO not working - need to properly instantiate AwsInstance
# verify chef::resource::awsinstance
aws_ebs_volume ref_volume.name do
  action [:attach, :detach]
  machine lazy { instance = AwsInstance.new
                 instance.volume_id(node.default['instance_id'])
                 instance
               }
  device '/dev/xvdf'
end

# reinitialize instance and destroy
aws_instance ref_machine.name do
  instance_id lazy { node.default['instance_id'] }
  action :delete
end

aws_ebs_volume ref_volume.name do
  action :delete
end

aws_key_pair aws_key.name do
  action :delete
end
