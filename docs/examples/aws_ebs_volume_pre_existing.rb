require 'chef/provisioning/aws_driver'

with_driver 'aws::us-west-2'

aws_key_pair 'ref-key-pair-ebs'

ref_machine1 = machine 'ref-machine-1'

# use resource to create aws volume
aws_ebs_volume 'ref-volume-ebs' do
  action :create
  availability_zone 'us-west-2a'
  size 1
end

# yup
ruby_block 'store volume id and delete ebs volume data bag' do
  block do
    ref_volume = data_bag_item('aws_ebs_volume', 'ref-volume-ebs')
    node.default['volume_id'] = ref_volume['reference']['id']
    ebs_volume_db_item = Chef::DataBagItem.new
    ebs_volume_db_item.destroy('aws_ebs_volume', 'ref-volume-ebs')
  end
end

# set volume_id.  since the data bag has been deleted the volume
# will be treated like a pre-existing volume
aws_ebs_volume 'vol-idontexistyet' do
  volume_id lazy { node['volume_id'] }
  action [:attach, :delete]
  machine ref_machine1.name
  device '/dev/xvdf'
end

machine ref_machine1.name do
  action :destroy
end

aws_key_pair 'ref-key-pair-ebs' do
  action :delete
end
