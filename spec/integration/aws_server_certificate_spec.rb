require 'spec_helper'

describe Chef::Resource::AwsServerCertificate do
  extend AWSSupport

  # http://openssl.6102.n7.nabble.com/create-certificate-chain-td44046.html
  # Follow those instructions except the chain should be `ca-int.crt` only
  # instead of concatenated intermediate and root

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "without a VPC" do
      cert_string = <<-CERT
-----BEGIN CERTIFICATE-----
MIICyjCCAbICAnyXMA0GCSqGSIb3DQEBDQUAMCcxJTAjBgNVBAMTHENoZWZQcm92
aXNpb25pbmdJbnRlcm1lZGlhdGUwHhcNMTcwODI0MTY0NTQyWhcNMjIwODIzMTY0
NTQyWjAuMQ4wDAYDVQQDEwVhbGljZTEcMBoGCSqGSIb3DQEJARYNYWxpY2VAY2hl
Zi5pbzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKxeXpigv/i4OWPB
kIBV3+HrKnEh05uEaq4UfJw0p6opKs4hyc92SvcFge4YBcLRbzhyMY5fUZAJXEla
csb6lEs2DMlW/KZGvfSMts2tVNbFVSsIsuSfhHVr9kemE42RPrtsO/0chOk2P/dl
P/KvXRF9AtEQe27/CWnJywCkP6tT6baZM6X+GGgAPUHvxN4BmJzz6uHpMVH+rBbb
t9ruLoSdX0zbaTRLesBC5Hc8uK2wzvDx0pUj+aKcWg5mtPBT6yReH6D5ePV2Jf10
9FGKMqPN6tOO6ZyAIWuKx3v09JzxmWGxNEyR65SNiI+ft092UFEKXYfgK58HZlWj
pBcOsHECAwEAATANBgkqhkiG9w0BAQ0FAAOCAQEAY1KXZv35hUER0WZz7JMKlvhI
IUpfB2NibP9G5LhtxFY1fa+MLp9mJ+yI3hg0x+6xBPTiPDGVpFdJ+LH/mKWxsaWT
17ZRGOeG2gZAlGr8Y8IMuR5cv2fmG6zCObMFxFR89pKvAYR+H5RFcHBg/N86SX6D
/KKNXu+NC9z/lrNVU6J/XUCk54YdmjMvadHs1aJp6NWH7LI9df27AlBGLnRc/w04
agCh4aCsjczD2YeBVl6idws/InYbSwhz7x9zXz2qB3BbI3psgBfJQQcJukulVGza
RkD993U+CJpJMDbpIGRe9lXe33R3tGbbvfa4FaXZlZgoKCrE21SCb2hxlNG2+w==
-----END CERTIFICATE-----           
CERT

      private_key_string = <<-KEY
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEArF5emKC/+Lg5Y8GQgFXf4esqcSHTm4RqrhR8nDSnqikqziHJ
z3ZK9wWB7hgFwtFvOHIxjl9RkAlcSVpyxvqUSzYMyVb8pka99Iy2za1U1sVVKwiy
5J+EdWv2R6YTjZE+u2w7/RyE6TY/92U/8q9dEX0C0RB7bv8JacnLAKQ/q1Pptpkz
pf4YaAA9Qe/E3gGYnPPq4ekxUf6sFtu32u4uhJ1fTNtpNEt6wELkdzy4rbDO8PHS
lSP5opxaDma08FPrJF4foPl49XYl/XT0UYoyo83q047pnIAha4rHe/T0nPGZYbE0
TJHrlI2Ij5+3T3ZQUQpdh+ArnwdmVaOkFw6wcQIDAQABAoIBAEz8TTXQPk3BQmiq
sHaRZFBML4Wd/RwttVQQ9GL0JZqbjnHIp5FQnUTdId4Mvq33yrwkTLvxGMXDWIOu
sSrsCkXZWzal8mv1lqveGVuduhG+yz5QQU5ZbNjhInt30q3dHG6rddOj5D0hLMq7
XyduaZwBALwNp4O4xySHq3Ka6ZEESpnY5o0hjclS7hAsiFnSW1/jI+yxPg6iS5T2
VzU92m1S/yixWn3jlqPRBjjt4YxCwoi+8D5c3wt/91N6hUWrIMFRHuvBfMCibWia
zquD022jCTkeW8S385ErYVHMLmZvXDcL0lwekoMMpL9TlTkapggz0desfVKt2aB5
mnpDPJECgYEA3uXxptejw1QPJhpuEdXnLEjsOTl3wvtHZIGZzsIwgoScFEjSbQgb
+06Z7wo6QXnYqJPwt8jbdlyYLogcaBboFIAb7XAOyndliUEffgL855WM3jY5j04G
ON3zGNXNQnnsgvWevs+bv17ZbEyqV8UiiolDCF4xn4CnP1y1nDJe44UCgYEAxfdp
aD+DvGcMIRa1mfaCVLrTCWyThAwKbLK9jJqmvj4JJIBwwMcBBsYarAfuzzyxRH9B
+QlNVkFdB4pME+mAWj7TQLXVK81RetqcL/7+yebMJ0MJPRGHXaQ+p2Nv8ZLoYMRj
MDruVLTXOg8XuN1RW4c8SmauaE2KXaYNUuzZXv0CgYEAwTy38tyfrIcDWxUut2ep
skrGABZCLVeK3Sc+IHFZfM1aQnufccbF+2h5KzLCrmDj48HdvnbzS/maNTzq45J4
QM2PaJjtObmo3QUIOEZ+2oZcSYjY/dO2sTY5uh4ghLEOyboGlYWGkLG57JnKU60j
9NZqtqZyfsUaOWQ2TeOdP8ECgYEAxW6J4T32096xag6L7pC6SmZIMg3m0LpxaxaX
k7JouTKFS7IMwTW3AFpyHz+KG4QcBoQj94ofZvapIOv8E5+8MkSVyuONRbHuoOeE
/RkCYbmbwUxJ2m2w4uL62VWCPxqURm2VvnQHXNM+Etkaf3O5v96PcmQVbFBovhzt
DNbJssECgYBIAFB3J66cZH3zBfyanHwYMPlTupxUBTsN19UCAK7MZqA5kbqG7b7Q
cKPrgR7gibLvaxj22lvD8uEICMGy6g8s3+PyDwcw5PNrKOdIkRrYQxTFtfs1JRCa
6kM8q32f1I3qd31zbpoDBHq+Se2RSaLbmoIAFqDSCWyeUHydALo2kw==
-----END RSA PRIVATE KEY-----      
KEY

      certificate_chain_string = <<-CHAIN
-----BEGIN CERTIFICATE-----
MIICuzCCAaMCAgh0MA0GCSqGSIb3DQEBDQUAMB8xHTAbBgNVBAMTFENoZWZQcm92
aXNpb25pbmdSb290MB4XDTE3MDgyNDE2NDUwNloXDTIyMDgyMzE2NDUwNlowJzEl
MCMGA1UEAxMcQ2hlZlByb3Zpc2lvbmluZ0ludGVybWVkaWF0ZTCCASIwDQYJKoZI
hvcNAQEBBQADggEPADCCAQoCggEBANl0H4XaW5iendZmf7r+QgztzwoEzuG1gyXO
SmO+gvrreo9C/lf6zA7x2tfWVs/bBIILpeJxOz1OzAid12o39bAREGxhcUNjQAcP
My82JmZpbu/xc6m2HoG9ycuM845MMp/dPO+iXZ6WEOHWTkdwu6u7HvxJAzMjvtOl
wLonJNlHDQ3toVLYb2PbiHxivqdTiNxdTATctKkzfU9An3XcPtBlPz2C6BVEjpIc
owlrA4UwTQLMFVCUhDKZvsO11UP2fhCjI0FIu7I1VEeWwEuZwdnhGsFg0IfH8YoE
VjioKcaKQm1Re517lePyLE3fw+sEH1+8osxE+xVT/5EMxqdU2jMCAwEAATANBgkq
hkiG9w0BAQ0FAAOCAQEAQIXWBs8m8U3Vp0rrGP5fIXqw680rf0Dhe9vz5ZnS7oJh
7/OWQtOG1YqsUNLMvbTUnilILgrckET280trfDg3/ucAwb5ScrBD3yja6CeGN5fo
gtw2MXUV3eA9ByAD4XKIWSvaROdHj+5wiCKWKMGvrSEPay5xEJm54VcALXHGk+Vf
jFNHTa/YFrlDXXupmI8HCYKwXrcooNcLuIkEmZIPX99s1vjFVT8oRdYLwFGt7AVC
ufkpMTlf/J9WjsabI5O+fzJYgdVm7QUq8Dg3tiM0RcZtO2cWus4DZl/KQkZx84f1
WGXzC2zbuS6DI9QPgkLeQ11O2kaeMqkNy6Tzr88XfA==
-----END CERTIFICATE-----      
CHAIN

      it "creates a cert" do
        expect_recipe {
          aws_server_certificate "test-cert" do
            certificate_body cert_string
            private_key private_key_string
            certificate_chain certificate_chain_string
          end
        }.to create_an_aws_server_certificate("test-cert",
                                              :certificate_body => cert_string.strip,
                                              :certificate_chain => certificate_chain_string.strip
                                             ).and be_idempotent
      end

      it "creates a cert without a certificate_chain" do
        expect_recipe {
          aws_server_certificate "test-cert" do
            certificate_body cert_string
            private_key private_key_string
          end
        }.to create_an_aws_server_certificate("test-cert",
                                              :certificate_body => cert_string.strip,
                                              :certificate_chain => nil
                                             ).and be_idempotent
      end
    end
  end
end
