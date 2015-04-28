# Chef Provisioning AWS

This README is a work in progress.  Please add to it!

# Resources

TODO: List out weird/unique things about resources here.  We don't need to document every resource
because users can look at the resource model.

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

## aws_key_pair

TODO - document how to specify an existing local key 

## Machine Options

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

# Running Integration Tests

To run the integration tests execute `bundle exec rake integration`.  If you have not set it up,
you should see an error message about a missing environment variable `AWS_TEST_DRIVER`.  You can add
this as a normal environment variable or set it for a single run with `AWS_TEST_DRIVER=aws::eu-west-1
bundle exec rake integration`.  The format should match what `with_driver` expects.

You will also need to have configured your `~/.aws/config` or environment variables with your
AWS credentials.

This creates real objects within AWS.  The tests make their best effort to delete these objects
after each test finishes but errors can happen which prevent this.  Be aware that this may charge
you!

If you find the tests leaving behind resources during normal conditions (IE, not when there is an
unexpected exception) please file a bug.  Most objects can be cleaned up by deleting the `test_vpc`
from within the AWS browser console.
