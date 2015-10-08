require 'spec_helper'

describe Chef::Resource::AwsServerCertificate do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "without a VPC" do

      cert_string = "-----BEGIN CERTIFICATE-----\nMIIDejCCAmICCQCpupMy/LKfLTANBgkqhkiG9w0BAQUFADB/MQswCQYDVQQGEwJV\nUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHU2VhdHRsZTENMAsGA1UE\nChMEQ2hlZjEMMAoGA1UECxMDRGV2MQ4wDAYDVQQDEwVUeWxlcjEcMBoGCSqGSIb3\nDQEJARYNdHlsZXJAY2hlZi5pbzAeFw0xNTA4MDQwMDI1NDFaFw0xNjA4MDMwMDI1\nNDFaMH8xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH\nEwdTZWF0dGxlMQ0wCwYDVQQKEwRDaGVmMQwwCgYDVQQLEwNEZXYxDjAMBgNVBAMT\nBVR5bGVyMRwwGgYJKoZIhvcNAQkBFg10eWxlckBjaGVmLmlvMIIBIjANBgkqhkiG\n9w0BAQEFAAOCAQ8AMIIBCgKCAQEAz4gFxNSzwwwYrYTTOCNVQL/agpIXmQKKtkE7\n+Up+waOdSR2iZvgc4fowAqQQ5dtVtur6LEA2LDlLILE+7MhlBxPc3V99lhi5p/Pv\neGCPI7k9sYT0iPJwiqvW+/nCo93QoNpUUDgb6WpT/RENFESn99nTE5NjxNx560aq\nSxAPHTogJEz3wC8c6mQQoANOuXzNb41wvOCUI7Tku76AQ9uECFUjtYpXpx8komaY\nAPtwzr87LGdSysE75roagews2MzAJgGG16oUBsJzT45MlIyQorN3AjoZ3fze6kop\nOhAWeYUM61rwTq7JtLXtBG/9yJzTd/eWU8c4cSK8zePx48X9TQIDAQABMA0GCSqG\nSIb3DQEBBQUAA4IBAQBXJQSpDkjxyljnSWjBur4XikLlFuEpdAdu0MILM3GnS3rT\ntoCVPG2U1d+KkhYG0Y9TBxHpK+3lDGYNyFYJN0STzL4cFzMgQlmZKFhVi/YJWKYO\nj9baIB3dy2k8b2XdDe3WxyycQpHjHhFPqpOTMGNV/1PwJNZGQEjc/svr8EalxvZB\neMb3Kk94K7yohvhT+Ze//rr4ArlM1zvEv3QMwSuyJBA2gtH7FgFKWohZnubW+3uc\n9W/Ux/3O1+BKDWp6zyqn/b2SSF51Jt3tSCF+hIMKYeJnJojY/AF9tQ+DtE8EKYRD\n/qzXX2MQLbhm1AzLt4PN63r96ADYlHhOJGNa9ocS\n-----END CERTIFICATE-----"
      private_key_string = "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAz4gFxNSzwwwYrYTTOCNVQL/agpIXmQKKtkE7+Up+waOdSR2i\nZvgc4fowAqQQ5dtVtur6LEA2LDlLILE+7MhlBxPc3V99lhi5p/PveGCPI7k9sYT0\niPJwiqvW+/nCo93QoNpUUDgb6WpT/RENFESn99nTE5NjxNx560aqSxAPHTogJEz3\nwC8c6mQQoANOuXzNb41wvOCUI7Tku76AQ9uECFUjtYpXpx8komaYAPtwzr87LGdS\nysE75roagews2MzAJgGG16oUBsJzT45MlIyQorN3AjoZ3fze6kopOhAWeYUM61rw\nTq7JtLXtBG/9yJzTd/eWU8c4cSK8zePx48X9TQIDAQABAoIBAA8teoaHq9Hy+4cN\nNMlhRCXlIhz0hEdLeUuU/8benOCaj7E+OpdfQ/V+763xw86buOwUyVEdLRkU45qz\ne8+jZEgdOsTx6+RjUIio/XWHUlChhpKKD7xIRtTNdn6dKJAFc/GfphTr1Za/kP7s\nFVHLJ6Gny5kd6WkHWt9LHr84oHJZoSjR6YDYdSTL+NtVTwqsKj4EfNY8JAPJI/xI\n9A9t57pvXzwdiya/vXPGytgwkHC/HHWp2sgFvKtJUzuGH0ETDlys9mvXoVQeZ0d9\njhzwIwWAoyvTY9FsUBTCD0aO8r2ylsDVIo2b2cEAZ0Z77OGMUt4sock88sDIICnO\nZVjhV50CgYEA8hKTHpI5ENFvYrTckrc+PnPw7B7xHCCB84ut/CiwzawYRjUx/mtm\nCYYR1xAXdEFrBC21i4Ri8LAIrAQiFGydg2oh4ZQcnEMGKZ0F2VXlsidVNN2tW/50\n8kEaPHPVeP6Trt2kPtpQnhDcuQXbPmOgPBIY2j6nu/Go25e8eICkfhsCgYEA23iy\n8Og1SWZlV5b3ZFyolZiZ9kp0cwyXUGWxUZyw33gBmK6BFkscflI1vfNutxnTDjNl\nALLRoAeIApvXTMFOMUPJsDk90pO7rdlfLznU27lKPyCDkvDGmjCvGGDXrnvi+cc3\ngB3ERfrLJCMoMk9lyg7/KEzzsIjvtTRO79atCLcCgYAGT/+wI2YDj0KVU1wRI2An\nJsTYk3H8Jsjcvf66faEmq98yLX7xQIG3q9xZPF0wNeiBgmOikMA3wI9pVO5ClBaD\nb8gUZtVcKc9GVIbrhPbpb2ckasdzh64rBxGVE/w0HIdjXvpCfVTu2ke3N3ThKp3q\nExq8zjd3ijS6DTnn9orTkwKBgQCxVwpgl4HXWaIx8I7ezfB7UN+3n9oQzO/HyyRI\n6fAR4oqHsRolxXO0rwE2B+pCkd907hqDQfsY8Hz6fqquHtTsAfaLKvXFnhJdG/RJ\n2NUi5soT0FYA+gXAue4CKN6e4wQ5CLzUDTl3wns7LB1i6b06VHvhOK0AzOXE6guO\nyUzwaQKBgDCrGz6IrxEUWl6C14xNNRZBvYTY9oCQpUnup1gMxATJZm4KelKvtKz2\nU1MXpc1i395e+E+tjNAQg0JcBmwkHOMl8c/oAESWPxi11ezalGtUXjIgjBkqqNUE\n/uFqRpNFGwI09JolIqhBTgPWFq6MuuPDJ9IIGJZDQoGEBKmu0k2r\n-----END RSA PRIVATE KEY-----"

      it "creates a cert" do
        expect_recipe {
          aws_server_certificate "test-cert" do
            certificate_body cert_string
            private_key private_key_string
          end
        }.to create_an_aws_server_certificate("test-cert",
                                              :certificate_body => cert_string#.delete("\n")
                                             ).and be_idempotent
      end
    end
  end
end
