require 'chef/provisioning/aws_driver'

with_driver 'aws::us-west-2'

aws_key_pair 'ref-key-pair-ebs'

with_machine_options :bootstrap_options => { :key_name => 'ref-key-pair-ebs' }

machine 'ref-machine-1'
machine 'ref-machine-2'


# create and attach ebs volume with machine
machine 'ref-machine-3' do
  machine_options bootstrap_options: {
    block_device_mappings: [{
      device_name: '/dev/xvdf',
      ebs: {
        volume_size: 1 # 1 GB
      }
    }]
  }
end

# machine_batch do
#   machines 'ref-machine-1', 'ref-machine-2'
# end

# create volume
aws_ebs_volume 'ref-volume-ebs' do
  availability_zone 'a'
  size 1
end

# attach to machine
aws_ebs_volume 'ref-volume-ebs' do
  machine 'ref-machine-1'
  device '/dev/xvdf'
end

# reattach to different device
aws_ebs_volume 'ref-volume-ebs' do
  device '/dev/xvdg'
end

# reattach to different machine
aws_ebs_volume 'ref-volume-ebs' do
  machine 'ref-machine-2'
  device '/dev/xvdf'
end

# skip reattachment attempt
aws_ebs_volume 'ref-volume-ebs' do
  machine 'ref-machine-2'
  device '/dev/xvdf'
end

# create and attach
aws_ebs_volume 'ref-volume-ebs-2' do
  availability_zone 'a'
  size 1
  machine 'ref-machine-1'
  device '/dev/xvdf'
end

# detach
aws_ebs_volume 'ref-volume-ebs' do
  machine false
end

# delete volumes
['ref-volume-ebs', 'ref-volume-ebs-2'].each { |volume|
  aws_ebs_volume volume do
    action :destroy
  end
}

machine_batch do
  machines 'ref-machine-1', 'ref-machine-2'
  action :destroy
end

aws_key_pair 'ref-key-pair-ebs' do
  action :destroy
end
