require 'chef/provisioning/aws_driver'

with_driver 'aws::us-east-1'

# this will fail. we use the domain name as a data bag key, but Route 53 will add a trailing dot, and
# furthermore Route 53 is content to have two HostedZones named "feegle.com.". in order to prevent unexpected
# results, we prevent domain names from ending with a dot.
aws_route53_hosted_zone "feegle.com."

# a corollary to this is that chef-provisioning-aws does not support having two AWS HostedZones with the same
# zone name, even though AWS itself does support this.

# create a Route 53 Hosted Zone (which AWS will normalize to "feegle.com.").
aws_route53_hosted_zone "feegle.com"

# create a Route 53 Hosted Zone with a CNAME record.
# TODO(9/17/2015): maybe add an RRS attribute to append the enclosing zone name (like 'append_zone_name true').
aws_route53_hosted_zone "feegle.com" do
  record_sets {
    aws_route53_record_set "some-hostname CNAME" do
      rr_name "some-api-host.feegle.com"
      type "CNAME"
      ttl 3600
      resource_records ["some-other-host"]
    end
  }
end

# Route 53 ResourceRecordSets are mostly analogous to DNS resource records (RRs). in the AWS Console they look
# like first-class objects, but they don't have an AWS ID: only the RR name. (In other words, you can't have
# an A record and a TXT record both pointing to 'snarf.feegle.com'.)

# aws_route53_record_sets in the same aws_route53_hosted_zone resource are run as a transaction by AWS. You
# cannot currently (9/17/15) define an aws_route53_record_set elsewhere and refer to it here, and in fact I'm
# not sure if that's possible. you could probably define the record_sets block elsewhere and pass it to the
# resource, though.
aws_route53_hosted_zone "feegle.com" do
  record_sets {
    # the resource name can serve as the RR name.
    aws_route53_record_set "tiffany" do
      type "CNAME"
      ttl 1800
      resource_records ["a-different-host"]    # always an array of strings.
    end

    # or you can specify the RR name separately.
    aws_route53_record_set "aching" do
      rr_name "tiffany.feegle.com"
      type "A"
      ttl 3600
      resource_records [
        "141.222.2.2",
        "192.168.10.89"
      ]
    end

    # the RecordSet inherits the zone name, but you can specify it if you like.
    aws_route53_record_set "tiffany.feegle.com" do
      type "CNAME"
      ttl 1800
      resource_records ["a-different-host"]
    end

    # however, this is an error, since the domain here doesn't match the parent HostedZone.
    aws_route53_record_set "tiffany.not-feegle.com" do
      type "CNAME"
      ttl 1800
      resource_records ["a-different-host"]
    end
  }
end

# some RR types have restrictions on the resource_records values:
#
#  MX:    "<integer priority> <mail server hostname>"
#  SRV:   "<integer priority> <integer weight> <integer port> <server hostname>"
#  CNAME: may only have a single value.
#
# chef-provisioning-aws does some validation for these, but we let AWS handle much of it.

# delete an individual RecordSet. the values must be the same as those currently in Route 53, or else an AWS
# error will bubble up.
aws_route53_hosted_zone "feegle.com" do
  record_sets {
    aws_route53_record_set "some-hostname CNAME" do
      action :destroy
      rr_name "some-api-host.feegle.com"
      type "CNAME"
      ttl 1800
      resource_records ["a-different-host"]
    end
  }
end

# calling :destroy on a zone will unconditionally wipe all of its RecordSets.
aws_route53_hosted_zone "feegle.com" do
  action :destroy
end

# Compressing Recipes
# you can set defaults for a zone that will be inherited (or overridden) by RecordSets.
# currently supported defaultable attributes are :ttl and :type.
aws_route53_hosted_zone "feegle.com" do
  defaults ttl: 1800, type: "CNAME"

  record_sets {
    # type CNAME, TTL 1800.
    aws_route53_record_set "host1" do
      resource_records ["a-different-host"]
    end

    # type A, TTL 1800.
    aws_route53_record_set "host2" do
      type "A"
      resource_records ["8.8.8.8"]
    end
  }
end
