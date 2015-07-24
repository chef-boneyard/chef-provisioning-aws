# Chef Provisioning AWS

This README is a work in progress.  Please add to it!

# Prerequesites

## Credentials

AWS credentials should be specified in your `~/.aws/credentials` file as documented [here](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-config-files).  We support the use of profiles as well.  If you do not specify a profile then we use the `default` profile.

You can specify a profile as the middle section of the semi-colon seperated driver url.  For example, a driver url of `aws:staging:us-east-1` would use the profile `staging`.

# Resources

TODO: List out weird/unique things about resources here.  We don't need to document every resource
because users can look at the resource model.

TODO: document `aws_object` and `get_aws_object` and how you can get the aws object for a base
chef-provisioning resource like machine or load_balancer

## aws_key_pair

TODO - document how to specify an existing local key 

## aws_vpc

If you specify `internet_gateway true` the VPC will create and manage its own internet gateway.
Specifying `internet_gateway false` will delete that managed internet gateway.

Specifying `main_routes` without `main_route_table` will update the 'default' route table
that is created when AWS creates the VPC.

Specifying `main_route_table` without specifying `main_routes` will update the main route
association to point to the provided route table.

If you specify both `main_routes` and `main_route_table` we will update the `main_route_table`
to have the specified `main_routes`.  IE, running

```ruby
aws_route_table 'ref-main-route-table' do
  vpc 'ref-vpc'
  routes '0.0.0.0/0' => :internet_gateway
end

aws_vpc 'ref-vpc' do
  main_route_table 'ref-main-route-table'
  main_routes '0.0.0.0/1' => :internet_gateway
end

aws_vpc 'ref-vpc' do
  main_routes '0.0.0.0/2' => :internet_gateway
end
```

will cause resource flapping.  The `ref-main-route-table` resource will set the routes to `/0`
and then the vpc will set the routes to `/1`.  Then because `ref-main-route-table` is set
to the main route for `ref-vpc` the third resource will set the routes to `/2`.

The takeaway from this is that you should either specify `main_routes` on your VPC and only
manage the routes through that, OR only specify `main_route_table` and manage the routes
through the `aws_route_table` resource.

### Purging

If you specify `action :purge` on the VPC it will attempt to delete ALL resources contained in this
VPC before deleting the actual VPC.

A potential danger of this is that it does not delete the data bag entries for tracked AWS objects.
If you `:purge` a VPC and it has `aws_route_table[ref-route]` in it, the data bag entry for
`ref-route` is not automatically destroyed.  Purge is most useful for testing to ensure no objects
are left that AWS can charge for.

# Machine Options

TODO - Finish documenting these

You can pass machine options that will be used by `machine`, `machine_batch` and `machine_image` to
configure the machine.  These are all the available options:

```ruby
with_machine_options({
  bootstrap_options: {
    key_name: 'ref-key-pair',
    ...
  },
  ...
})
```

This options hash can be supplied to either `with_machine_options` or directly into the `machine_options`
attribute.

# Specifying a Chef Server

See [Pointing Boxes at Chef Servers](https://github.com/chef/chef-provisioning/blob/master/README.md#pointing-boxes-at-chef-servers)

# Tagging Resources

## Aws Resources

All resources which extend Chef::Provisioning::AWSDriver::AWSResourceWithEntry support the ability
to add tags, except AwsEipAddress.  AWS does not support tagging on AwsEipAddress.  To add a tag
to any aws resource, us the `aws_tags` attribute and provide it a hash:

```ruby
aws_ebs_volume 'ref-volume' do
  aws_tags company: 'my_company', 'key_as_string' => :value_as_symbol
end

aws_vpc 'ref-vpc' do
  aws_tags 'Name' => 'custom-vpc-name'
end
```

The hash of tags can use symbols or strings for both keys and values.  The tags will be converged
idempotently, meaning no write will occur if no tags are changing.

We will not touch the `'Name'` tag UNLESS you specifically pass it.  If you do not pass it, we
leave it alone.

## Base Resources

Because base resources from chef-provisioning do not have the `aws_tag` attribute, they must be
tagged in their options:

```ruby
machine 'ref-machine-1' do
  machine_options :aws_tags => {:marco => 'polo', :happyhappy => 'joyjoy'}
end

machine_batch "ref-batch" do
  machine 'ref-machine-2' do
    machine_options :aws_tags => {:marco => 'polo', :happyhappy => 'joyjoy'}
    converge false
  end
  machine 'ref-machine-3' do
    machine_options :aws_tags => {:othercustomtags => 'byebye'}
    converge false
  end
end

load_balancer 'ref-elb' do
  load_balancer_options :aws_tags => {:marco => 'polo', :happyhappy => 'joyjoy'}
end
```

See `docs/examples/aws_tags.rb` for further examples.

# Looking up AWS objects

## \#aws\_object

All chef-provisioning-aws resources have a `aws_object` method that will return the AWS object.  The AWS
object won't exist until the resource converges, however.  An example of how to do this looks like:

```ruby
my_vpc = aws_vpc 'my_vpc' do
  cidr_block '10.0.0.0/24'
  main_routes '0.0.0.0/0' => :internet_gateway
  internet_gateway true
end

my_sg = aws_security_group 'my_sg' do
  vpc lazy { my_vpc.aws_object.id }
  inbound_rules '0.0.0.0/0' => [ 22, 80 ]
end

my_subnet = aws_subnet 'my_subnet' do
  vpc lazy { my_vpc.aws_object.id }
  cidr_block '10.0.0.0/24'
  availability_zone 'eu-west-1a'
  map_public_ip_on_launch true
end

machine 'my_machine' do
  machine_options(
    lazy do
      {
        bootstrap_options: {
          subnet_id: my_subnet.aws_object.id,
          security_group_ids: [my_sg.aws_object.id]
        }
      }
    end
  )
end
```

Note the use of the `lazy` attribute modifier.  This is necessary because when the resources are compiled
the aws_objects do not exist yet, so we must wait to reference them until the converge phase.

## \#lookup\_options

You have access to the aws object when necessary, but often it isn't needed.  The above example is better
written as:

```ruby
aws_vpc 'my_vpc' do
  cidr_block '10.0.0.0/24'
  main_routes '0.0.0.0/0' => :internet_gateway
  internet_gateway true
end

aws_security_group 'my_sg' do
  vpc 'my_vpc'
  inbound_rules '0.0.0.0/0' => [ 22, 80 ]
end

aws_subnet 'my_subnet' do
  vpc 'my_vpc'
  cidr_block '10.0.0.0/24'
  availability_zone 'eu-west-1a'
  map_public_ip_on_launch true
end

machine 'my_machine' do
  machine_options bootstrap_options: {
    subnet_id: 'my_subnet',
    security_group_ids: ['my_sg']
  }
end
```

When specifying `bootstrap_options` and any attributes which reference another aws resource, we
perform [lookup_options](https://github.com/chef/chef-provisioning-aws/blob/master/lib/chef/provisioning/aws_driver/aws_resource.rb#L63-L91).
This tries to turn elements with names like `vpc`, `security_group_ids`, `machines`, `launch_configurations`,
`load_balancers`, etc. to the correct AWS object.

## Looking up chef-provisioning resources

The base chef-provisioning resources (machine, machine_batch, load_balancer, machine_image) don't
have the `aws_object` method defined on them because they are not `AWSResource` classes.  To
look them up use the class method `get_aws_object` defined on the chef-provisioning-aws specific
resource:

```ruby
machine_image 'my_image' do
  ...
end

ruby_block "look up machine_image object" do
  block do
    aws_object = Chef::Resource::AwsImage.get_aws_object(
      'my_image',
      run_context: run_context,
      driver: run_context.chef_provisioning.current_driver,
      managed_entry_store: Chef::Provisioning.chef_managed_entry_store(run_context.cheffish.current_chef_server)
    )
  end
end
```

To look up a machine, use the `AwsInstance` class, to look up a load balancer use the `AwsLoadBalancer`
class, etc.  The first parameter you pass should be the same resource name as used in the base
chef-provisioning resource.

Again, the AWS object will not exist until the converge phase, so the aws_object will only be
available using a `lazy` attribute modifier or in a `ruby_block`.

# Running Integration Tests

To run the integration tests execute `bundle exec rspec`.  If you have not set it up,
you should see an error message about a missing environment variable `AWS_TEST_DRIVER`.  You can add
this as a normal environment variable or set it for a single run with `AWS_TEST_DRIVER=aws::eu-west-1
bundle exec rspec`.  The format should match what `with_driver` expects.

You will also need to have configured your `~/.aws/config` or environment variables with your
AWS credentials.

This creates real objects within AWS.  The tests make their best effort to delete these objects
after each test finishes but errors can happen which prevent this.  Be aware that this may charge
you!

If you find the tests leaving behind resources during normal conditions (IE, not when there is an
unexpected exception) please file a bug.  Most objects can be cleaned up by deleting the `test_vpc`
from within the AWS browser console.
