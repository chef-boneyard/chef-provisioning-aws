require 'chef/provisioning/aws_driver'

with_driver 'aws::us-west-2'

machine 'ref-machine-1' do
  action :allocate
end

machine 'ref-machine-1' do
  machine_options aws_tags: {:marco => 'polo', :happyhappy => 'joyjoy'}
  converge false
end

machine 'ref-machine-1' do
  machine_options aws_tags: {:othercustomtags => 'byebye'}
  converge false
end

machine 'ref-machine-1' do
  machine_options aws_tags: {:Name => 'new-name'}
  converge false
end

machine 'ref-machine-1' do
  action :destroy
end

machine_batch "ref-batch" do
  machine 'ref-machine-2' do
    machine_options aws_tags: {:marco => 'polo', :happyhappy => 'joyjoy'}
    converge false
  end
  machine 'ref-machine-3' do
    machine_options aws_tags: {:othercustomtags => 'byebye'}
    converge false
  end
end

load_balancer 'ref-elb' do
  load_balancer_options availability_zones: ['us-west-1a', 'us-west-1b']
end

load_balancer 'ref-elb' do
  load_balancer_options aws_tags: {:marco => 'polo', :happyhappy => 'joyjoy'}
end

load_balancer 'ref-elb' do
  load_balancer_options aws_tags: {:othercustomtags => 'byebye'}
end

load_balancer 'ref-elb' do
  action :destroy
end

machine_batch "ref-batch" do
  action :destroy
end

machine_image "ref-image" do
  image_options aws_tags: {:marco => 'polo', :happyhappy => 'joyjoy'}
end

# There is a bug where machine_images do not update - so we cannot update
# the tags on it
machine_image "ref-image" do
  image_options aws_tags: {:othercustomtags => 'byebye'}
end

machine_image "ref-image" do
  action :destroy
end
