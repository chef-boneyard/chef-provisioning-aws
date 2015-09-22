# Chef Provisioning AWS

This README is a work in progress.  Please add to it!

# Prerequesites

## Credentials

There are 3 ways you can provide your AWS Credentials.  We will look for credentials in the order from below and use the first one found.  This precedence order is taken from http://docs.aws.amazon.com/sdkforruby/api/index.html#Configuration:

1. Through the environment variables `ENV["AWS_ACCESS_KEY_ID"]`, `ENV["AWS_SECRET_ACCESS_KEY"]` and optionally `ENV["AWS_SESSION_TOKEN"]`
2. The shared credentials ini file.  The default location is `~/.aws/credentials` but you can overwrite this by specifying `ENV["AWS_CONFIG_FILE"]`.  You can specify 
multiple profiles in this file and select one with the `ENV["AWS_DEFAULT_PROFILE"]`
environment variable or via the driver url.  For example, a driver url of `aws:staging:us-east-1` would use the profile `staging`.  If you do not specify a profile then the `default` one is used.  Read
[this](http://blogs.aws.amazon.com/security/post/Tx3D6U6WSFGOK2H/A-New-and-Standardized-Way-to-Manage-Credentials-in-the-AWS-SDKs) for more information about profiles.
3. From an instance profile when running on EC2.  This accesses the local
metadata service to discover the local instance's IAM instance profile.

## Configurable Options

When using `machine_batch` with a large number of machines it is possible to overwhelm the AWS SDK until it starts returning `AWS::EC2::Errors::RequestLimitExceeded`.  You can configure the AWS SDK to retry these errors automatically by specifying

```ruby
chef_provisioning({:aws_retry_limit => 10})
```

in your client.rb for the provisioning workstation.  The default `:aws_retry_limit` is 5.

# Resources

TODO: List out weird/unique things about resources here.  We don't need to document every resource
because users can look at the resource model.

TODO: document `aws_object` and `get_aws_object` and how you can get the aws object for a base
chef-provisioning resource like machine or load_balancer

## aws_key_pair

You can specify an existing key pair to upload by specifying the following:

```ruby
aws_key_pair 'my-aws-key' do
  private_key_path "~boiardi/.ssh/my-aws-key.pem"
  public_key_path "~boiardi/.ssh/my-aws-key.pub"
  allow_overwrite false # Set to true if you want to regenerate this each chef run
end
```

## aws_launch_configuration

In the AWS SDK V1, you must specify `key_pair` instead of `key_name` when specifying the key name to use for machines in the auto scaling group.  This is fixed in V2 and uses `key_name` like machines do.

```ruby
aws_launch_configuration 'example-windows-launch-configuration' do
  image 'example-windows-image'
  instance_type 't2.medium'
  options security_groups: 'example-windows-sg',
    key_pair: 'my-key-name',
    ebs_optimized: false,
    detailed_instance_monitoring: false,
    iam_instance_profile: 'example-windows-role',
    user_data: <<-EOF
<powershell>
# custom powershell code goes here, executed at instance creation time
</powershell>
  EOF
end
```

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
  # See https://github.com/chef/chef-provisioning#machine-options for options shared between drivers
  bootstrap_options: {
    # http://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Resource.html#create_instances-instance_method
    # lists the available options.  The below options are the default
    image_id: "ami-5915e11d", # default for us-west-1
    instance_type: "t2.micro",
    key_name: "chef_default", # If not specified, this will be used and generated
    key_path: "~/.chef/keys/chef_default", # only necessary if storing keys some other location
    user_data: "...", # Only defaulted on Windows instances to start winrm
  },
  use_private_ip_for_ssh: false, # DEPRECATED, use `transport_address_location`
  transport_address_location: :public_ip, # `:public_ip` (default), `:private_ip` or `:dns`.  Defines how SSH or WinRM should find an address to communicate with the instance.
})
```

This options hash can be supplied to either `with_machine_options` or directly into the `machine_options`
attribute.

# Load Balancer Options

You can configure the ELB options by setting `with_load_balancer_options` or specifying them on each `load_balancer` resource.

```ruby
machine 'test1'
m2 = machine 'test2'
load_balancer "my_elb" do
  machines ['test1', m2]
  load_balancer_options({
    subnets: subnets,
    security_groups: [load_balancer_sg],
    listeners: [
      {
          instance_port: 8080,
          protocol: 'HTTP',
          instance_protocol: 'HTTP',
          port: 80
      },
      {
          instance_port: 8080,
          protocol: 'HTTPS',
          instance_protocol: 'HTTP',
          port: 443,
          ssl_certificate_id: "arn:aws:iam::360965486607:server-certificate/cloudfront/foreflight-2015-07-09"
      }
    ]
  })
```

The available parameters for `load_balancer_options` can be viewed in the [aws docs](http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/ELB/Client.html#create_load_balancer-instance_method).

NOTES:

1. You can specify either `ssl_certificate_id` or `server_certificate` in a listener but the value to both parameters should be the ARN of an existing IAM::ServerCertificate object.

# RDS Instance Options

### Additional Options

RDS instances have many options. Some of them live as first class attributes. Any valid RDS option that is not a first class attribute can still be set via a hash in `additional_options`.
*If you set an attribute and also specify it in `additional_options`, the resource will chose the attribute and not what is specified in `additional_options`.*

To illustrate, note that the following example defines `multi_az` as both an attribute and in the `additional_options` hash:

```
aws_rds_instance "test-rds-instance2" do
  engine "postgres"
  publicly_accessible false
  db_instance_class "db.t1.micro"
  master_username "thechief"
  master_user_password "securesecure"
  multi_az false
  additional_options(multi_az: true)
end
```

The above would result in a new `aws_rds_instance` with `multi_az` being `false`.

Additional values for `additional_options` can view viewed in the [aws docs](http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/RDS/Client.html#create_db_instance-instance_method).

### Specifying a DB Subnet Group for your RDS Instance

See [this example](docs/examples/aws_rds_subnet_group.rb) for how to set up a DB Subnet Group and pass it to your RDS Instance.

# Specifying a Chef Server

See [Pointing Boxes at Chef Servers](https://github.com/chef/chef-provisioning/blob/master/README.md#pointing-boxes-at-chef-servers)

# Tagging Resources

## For Recipe authors

All resources (incuding base resources like `machine`) that are taggable support an `aws_tags` attribute which accepts a single layer hash.  To set just the key of an AWS tag specify the value as nil.  EG, `aws_tags {my_tag_key: nil}`.  Some AWS objects cannot accept nil values and will automatically convert it to an empty string.

Some AWS objects (may EC2) view the `Name` tag as unique - it shows up in a `Name` column in the AWS console.  By default we specify the `Name` tag as the resource name.  This can be overridden by specifying `aws_tags {Name: 'some other name'}`.

You can remove all the tags _except_ the `Name` tag by specifying `aws_tags {}`.

Tag keys and values can be specified as symbols or strings but will be converted to strings before sending to AWS.

Examples:

```ruby
aws_ebs_volume 'ref-volume' do
  aws_tags company: 'my_company', 'key_as_string' => :value_as_symbol
end

aws_vpc 'ref-vpc' do
  aws_tags 'Name' => 'custom-vpc-name'
end
```

## For Resource Authors

To enable tagging support you must make specific changes to the Resource and Attribute.  For the Resource it needs to include the `attribute aws_tags`.  This should be done by `include Chef::Provisioning::AWSDriver::AWSTaggable` on the Resource.

The `AWSProvider` class will automatically try to call `converge_tags` when running the `action_create` method.  You should instantiate an instance of the `AWSTagger` and provide it a strategy depending on the client used to perform the tagging.  For example, an RDS Provider should define

```ruby
def aws_tagger
  @aws_tagger ||= begin
    rds_strategy = Chef::Provisioning::AWSDriver::TaggingStrategy::RDS.new(
      new_resource.driver.rds.client,
      construct_arn(new_resource),
      new_resource.aws_tags
    )
    Chef::Provisioning::AWSDriver::AWSTagger.new(rds_strategy, action_handler)
  end
end
def converge_tags
  aws_tagger.converge_tags
end
```

The `aws_tagger` method is used by the tests to assert that the object tags are correct.  These methods can be encapsulated in an module for DRY purposes, as the EC2 strategy shows.

Finally, you should add 3 standard tests for taggable objects - 1) Tags can be created on a new object, 2) Tags can be updated on an existing object with tags and 3) Tags can be cleared by setting `aws_tags {}`.  Copy the tests from an existing spec file and modify them to support your resource.  TODO make a module that copies these tests for us.  Right now it is complicated by the fact that some resources have required attributes that others don't.

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
