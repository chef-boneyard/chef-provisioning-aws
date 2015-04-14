# chef-provisioning-aws

An implementation of the AWS driver using the AWS Ruby SDK (v1).  It also implements a large number of AWS-specific resources such as:

* SQS Queues
* SNS Topics
* Elastic Load Balancers
* VPCs
* Security Groups
* Instances
* Images
* Autoscaling Groups
* SSH Key pairs
* Launch configs

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
