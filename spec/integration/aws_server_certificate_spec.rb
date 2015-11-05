require 'spec_helper'

describe Chef::Resource::AwsServerCertificate do
  extend AWSSupport

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "without a VPC" do
      cert_string = <<-CERT
-----BEGIN CERTIFICATE-----
MIIB+TCCAWICAQEwDQYJKoZIhvcNAQEFBQAwRTELMAkGA1UEBhMCQVUxEzARBgNV
BAgTClNvbWUtU3RhdGUxITAfBgNVBAoTGEludGVybmV0IFdpZGdpdHMgUHR5IEx0
ZDAeFw0xNTExMDMyMjQ3MzdaFw0xNjExMDIyMjQ3MzdaMEUxCzAJBgNVBAYTAkFV
MRMwEQYDVQQIEwpTb21lLVN0YXRlMSEwHwYDVQQKExhJbnRlcm5ldCBXaWRnaXRz
IFB0eSBMdGQwgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBAL8NfMueVw1x7cHs
a4vO1ci5Dm2X9dg1qdMS8kVrUBuQPrGk9uMEPWrh6gSdAmlrLdcazvYu3iRHJrEO
JISFWQ9Z0XOw/rhihoNwieZIbtfrTRIdzicRe3VRs/Jguq/S0bgXu2Kf0AYuBPSL
HEe3hOeAmoH7xpf40qmO/MfuveqDAgMBAAEwDQYJKoZIhvcNAQEFBQADgYEAll6t
vEPuBQi4SEzHWjtjySQlNdkMWfGYC3A992AAvPxP/o+MlJOvyIwxUNDzku5MeJPP
ey6ND1pPZVD38Yul6rRQJDUQFIAnQU2M7rNlgje/N9Fms2Z6NtnmlSi4KDf2xeUi
J7kHGXgdBKW1vixZyQuxB1VQ3C+fq1gqouzZ9g8=
-----END CERTIFICATE-----
CERT

      private_key_string = <<-KEY
-----BEGIN RSA PRIVATE KEY-----
MIICXQIBAAKBgQC/DXzLnlcNce3B7GuLztXIuQ5tl/XYNanTEvJFa1AbkD6xpPbj
BD1q4eoEnQJpay3XGs72Lt4kRyaxDiSEhVkPWdFzsP64YoaDcInmSG7X600SHc4n
EXt1UbPyYLqv0tG4F7tin9AGLgT0ixxHt4TngJqB+8aX+NKpjvzH7r3qgwIDAQAB
AoGANKyuTKGCVNWlfMMHP8uuC6JiBPtRr+PTx7tAir00n/TcJDRcUWj42gAhelYj
tRb004qzpxJy8sOfOk+w58ywKd2ZbbIPFif4K0bSBcv9+CQh3OpW77oLqS7lft/S
s1AVd5qaqVwj/2kChdusSxt/mou0hECeiDf8eBQbPi4pRPECQQD3p3VkwIeqWC+R
q/rcOEMxSSk972KEhWq6KRpGaB9TBX5cmQ0iP+zOxSSRY3qPr/8r2osBA5DsJOBZ
zZora2f5AkEAxX24tll5g23hooWAy3em/NTCGBOOdTIuUMc3hOnrF4ZpFEK8iVh0
M9NYQPv9He6xSMqQHlrL58L+kfODfL7dWwJBAIRpJHsZ9W8+dzCLozTbYBGZ7FMR
CruQGeAu2b2LLjRVW5pmun71bsee4E5bwcvRbb0ku+1u2q1nigx5wVQ1uQECQGzf
RxH3t35V+BqhYIRKnRsqqymctl8zX8cWXCwAzKJ2bb1GoStSQRVFAJUqlbqHmOJZ
ESQ6x8gnfjG1vhnqGpsCQQDuEWMaRtd9ELlRABX+IexFyGzA+qv3jREn9ZMdM2Cz
iI9GRQvTYypjW4k9qbUEzY2h5AubGfVHtDB1iL7X4XeM
-----END RSA PRIVATE KEY-----
KEY

      certificate_chain_string = <<-CHAIN
-----BEGIN CERTIFICATE-----
MIIB+TCCAWICAQEwDQYJKoZIhvcNAQEFBQAwRTELMAkGA1UEBhMCQVUxEzARBgNV
BAgTClNvbWUtU3RhdGUxITAfBgNVBAoTGEludGVybmV0IFdpZGdpdHMgUHR5IEx0
ZDAeFw0xNTExMDMyMjQ0NThaFw0xNjExMDIyMjQ0NThaMEUxCzAJBgNVBAYTAkFV
MRMwEQYDVQQIEwpTb21lLVN0YXRlMSEwHwYDVQQKExhJbnRlcm5ldCBXaWRnaXRz
IFB0eSBMdGQwgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBALwXCWh7I1tkNGRs
Ou7KuP6janhXZSvSK6+rmAzWMPPhpyuK1u9zOLnyHcOwmZPPQM+7fN7U/artYW7S
pq3LX4DJkZULDjTzkZvHM8hSHlVlyFDxtFWsoIE28fTArKsRQ6wrJZDkCNt4HQSk
2XPpYrtPwzdak5amNVrxrovyb1fNAgMBAAEwDQYJKoZIhvcNAQEFBQADgYEAMk6n
iESDfQisfc8M93WmVBOc2nnGsJ6tOSHaiLYhbyFGhQxW40B4PmqzkBVuC+zllviZ
sYCv9ZFuccoBZwrkfHIaJT292OYu3vu24++f3+GS+wkkxiY1gkObhaZzY5OGL7fU
7iR07ALoi4F3RHqOJZfY9XnsDo4gMruH9Z9TS+U=
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIICATCCAWoCCQD7KGMkmIek7TANBgkqhkiG9w0BAQUFADBFMQswCQYDVQQGEwJB
VTETMBEGA1UECBMKU29tZS1TdGF0ZTEhMB8GA1UEChMYSW50ZXJuZXQgV2lkZ2l0
cyBQdHkgTHRkMB4XDTE1MTEwMzIyMzkxOFoXDTE2MTEwMjIyMzkxOFowRTELMAkG
A1UEBhMCQVUxEzARBgNVBAgTClNvbWUtU3RhdGUxITAfBgNVBAoTGEludGVybmV0
IFdpZGdpdHMgUHR5IEx0ZDCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAq/sd
4ZdKcDJ6HD3LHt+46AGHcdQ7dEkt9DT01hHXG3SZ3StWx3g1CIvPQaJEdExOuyvU
b4Km88aQuBIHVyUrYgXds8hwRxe341dfXyoq/hEmPQjlWMOG9iUuSzrwygdfD1xw
OOPAS5c78LXQxls+5d7FQUsE0Zxq+0lBb8EbGgUCAwEAATANBgkqhkiG9w0BAQUF
AAOBgQAduqTZaJJaaPJL18TqhpAqix2qZ2Vjdw/oAal53g+nElUSGSzj2O/bFNRy
v432ZFGMxlGp0pYplU6e8HScR+7FfScueDTWFbK7llG3c/GGbcKuMutXZ3c96yYm
ceGGtSPaBVFCEHB4CM2vNvTcgRKuYQCnsnUpoS4FtdJ/2zmj2A==
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
