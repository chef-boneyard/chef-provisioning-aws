require 'spec_helper'

describe Chef::Resource::AwsServerCertificate do
  extend AWSSupport

  # http://openssl.6102.n7.nabble.com/create-certificate-chain-td44046.html

  when_the_chef_12_server "exists", organization: 'foo', server_scope: :context do
    with_aws "without a VPC" do
      cert_string = <<-CERT
-----BEGIN CERTIFICATE-----
MIICvjCCAaYCAkE4MA0GCSqGSIb3DQEBDQUAMBgxFjAUBgNVBAMTDVppbnRlcm1l
ZGlhdGUwHhcNMTcwMzE0MTQ0NzQzWhcNMjcwMzEyMTQ0NzQzWjAxMQ4wDAYDVQQD
EwVhbGljZTEfMB0GCSqGSIb3DQEJARYQYWxpY2VAcmFuZG9tLmNvbTCCASIwDQYJ
KoZIhvcNAQEBBQADggEPADCCAQoCggEBANQep8AvCZ4pLTDahkoQlvj+R8heF74e
vH34vfyU5TNrmoWTvlGDEwoCVEEcI8M4R2g9XYhB7SIqTDbJn5T6aLTsaTyMr/g0
p6Fiofd/k5pX5XuJDvya3e91Ixbu/qvvHyNlnLU1ba7HotqXcTJqMiW0rYEVE+PV
KctGByOlp5d34ytFguZZsPVR+Ma7HKb55ksIOkEa7VNQhL6hGRU+Ivnuvu/TJtmZ
lzb/9GUrs5L6JH2dMW9LUzvIT5rbAM2ntm4R1W+tU7Vb8gX6Q1ir5oTfRzENAqJZ
uFBGUaLhJzJhufD40c25cvgUVFQaRghFjHdqf2pqQsAS8LJYbj0uR8MCAwEAATAN
BgkqhkiG9w0BAQ0FAAOCAQEAEvmMK6C0AU2ww5t+/mS65laGTKdlVBvm3qqX1Fo1
MDBCVqVc51m69lwHgNxWzt8dcEFFT/d1xlDE2JWleSqH5/Dsj9AcYla4hTr5f76c
7M4LcYwuO+s/eTFkTl92DJiXVDczlsN/w1+lvt3Uw5ReKlMBMK+dbPUpZ/yl+NrU
3pf98aoP7m+oocl5lxksHse+klOkvlT26GfQ7JgGlWIO2xAhUtNkh6feFxZ1dP0O
45RTqOorOuxSV6PbgEahmsElRbAmxs/iSRi22340R7/rd8+g7Y+3olBFJsrzcYr4
1t8FiEUNUxoJIIPnHi/QIQxzmiQ3LZNEmtCnAPMeci1gug==
-----END CERTIFICATE-----
CERT

      private_key_string = <<-KEY
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA1B6nwC8JniktMNqGShCW+P5HyF4Xvh68ffi9/JTlM2uahZO+
UYMTCgJUQRwjwzhHaD1diEHtIipMNsmflPpotOxpPIyv+DSnoWKh93+Tmlfle4kO
/Jrd73UjFu7+q+8fI2WctTVtrsei2pdxMmoyJbStgRUT49Upy0YHI6Wnl3fjK0WC
5lmw9VH4xrscpvnmSwg6QRrtU1CEvqEZFT4i+e6+79Mm2ZmXNv/0ZSuzkvokfZ0x
b0tTO8hPmtsAzae2bhHVb61TtVvyBfpDWKvmhN9HMQ0Colm4UEZRouEnMmG58PjR
zbly+BRUVBpGCEWMd2p/ampCwBLwslhuPS5HwwIDAQABAoIBAQCrH9wHQCtLLD7n
5bNmtwGE+Gbir34KA/Pe0Lg8t8Y8eHedgbaNPegzL/PW3yO+z31UDAWT8lOjN2pq
3LfgUS/9nae8kGc6HwiJOvAdog9q+bQJuGWdxjZ7gw1+5+oOvQdq4APPcL3+vdGU
9Y39tQylvKAovd9g80wXUHRb/r04hKfYJmo6cVlz4Acz0iamiRDGCpFj3MIdYmNX
/iSbUUbu+KYzC0pNiNI4TXOdRGNSEcpHXAbmKK2HWR2w+U/duL3g4mzJDEbzI64g
fKC80Q+tesBwrzWnkXYaTWj422bngXuISpfVpkcW4mUloxLcSTVQyVSsXTB/SCvH
yHjuy615AoGBAPdWnnZiFZoYGtygkdUw3lFp5BGdxKY6nN9jAfJYE6rrJQSkwxCl
yaYLPlS/Pcepl/SQxphmWFvipzNa9fe85Uko57Zy1EHX/eWLpnLOjOefKxna9UIg
9xH/6o/fA0upQGDDRjUrHPnKodtulA/yuUqQrPLlf4qUCtoeaqsKoT5dAoGBANuM
TXEFry4EcU9jN4HmkZzkdNLtnLgHrgVX5VZx1cRhbs3mXKfxGpKWUy72Vwww3XUT
1sGelmYbsjMtB8NIZAyMeIdaqS7DsnAu1l4fHUs0RIHNa4pqszx5bi8iYo7PaN50
dmk2VtyO6eszbjjCkhWReFrYzMXBnIh7DKpT6fyfAoGAR9mTwtQPbmoeM4U5l/LQ
Qlo+dJeeLqPMOmBqilnnrLkOUeEDAW0HvQJ7IudDLSMpD1SXPGJOvLKE27hKx6LK
AIyvcyK8Yjw6d1owCh3SdN6aCLLAmGs3GrV7EDw6mtoZ54ISfRN/IVkp17KxtEhQ
Z0bL1uuwNzN2S5KWbgVyfckCgYBq556t8j6jAbbLGVzl/AfbhcL9EobFdbffEjWy
KiwVO/xgdlOX02dFCb3nmDw6y3CKmeZw0XAauFHFaZ/mD1Hoal4mSpcnFlPFHIl1
u2DgRcs2CXjcJaixQc/NU8j6ETTXXY5rHPKe41g0Fw8MxHGt3u/kDL1pbiVyr7gz
GDlPsQKBgQC+eFyfQnmcJHtB+aLy++JZsHtw03vIgmjSXYJYtqeyOYFdDD8gxTPv
M4qaRvofyGQ4CVSGScInEcc7S+ACWoRvNuc0APgS8UFmJ15/fpptdlA5irhrMLHA
3aH/+CxfbU+w/3tOoKvF91HIhsF+QXAUm7XNssGqYAe7m1gQYfGy4Q==
-----END RSA PRIVATE KEY-----
KEY

# TODO I cannot figure out how to get the fucking chain working
      certificate_chain_string = <<-CHAIN
-----BEGIN CERTIFICATE-----
MIICnjCCAYYCAkbgMA0GCSqGSIb3DQEBDQUAMBExDzANBgNVBAMTBkRhUm9vdDAe
Fw0xNzAzMTQxNDQ3MDJaFw0yNzAzMTIxNDQ3MDJaMBgxFjAUBgNVBAMTDVppbnRl
cm1lZGlhdGUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCmOmIWhS3b
OBEqCwvyPDitarl70Iq0uu0gvRrUzVy82CJEjIy2J1Kd9j4Pa5c+eeLEPg+kOLDc
P2yXijZ0P0vfatJM7sNHheCjyfa7Lw9zSV17GBludbh5s01PEFu/cxs3xs5zMBYr
juKla5TnYIjYyx9ryGEGQ+VYIO/0qWXKIcALh+V0iuYD9hzg34H6cPhsAjsJGv/0
0yE6b5Xoh3zeZ8NAD7JnuS0/725aTGudEiPEnbAYDL+U/g7KvsKu9t2dFADQgJSB
cx0a/vmrWtP1AEKvN5sGceOhj5HG3DAcbt+JMbnXwuuxBuQ6h66oGjtxednN27OI
GhC4gxf8Z1crAgMBAAEwDQYJKoZIhvcNAQENBQADggEBAISW3rxyrg1KpXaZa142
sHCav5/sdJLFTyV5bGfCis8lJGo3zHkigYMq9810gVtrjmtR47LU5WJR0ZyChOWu
T+Ea7tBa1ciGJ//pGDhTYCbWJM0ceFLsLpIHZqv4KTOzy9OgIA9XSmXVf1wkunCm
TVmV2vMwMVy3Qb+6AenvCAUOvfcZ2pd2CtHuJSmZXvDqjPW4IXX8fFmNbONjeVej
olBiH3xw95/Jw7T0IVTJ29KEBEYBk5sQtfBIvF4P81xaPjESLcXHI/lflc0+LPGP
v4lHNiOEDRjiFdultephOlPTZst/9vhe10KPAA+Ep9/VC4xvb/kf1vBCFPz3odqg
N7w=
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIDFzCCAf+gAwIBAgIJANas+XusVBBwMA0GCSqGSIb3DQEBDQUAMBExDzANBgNV
BAMTBkRhUm9vdDAeFw0xNzAzMTQxNDQ2MTlaFw0xNzA0MTMxNDQ2MTlaMBExDzAN
BgNVBAMTBkRhUm9vdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALFn
BJQuyEvjl1GFMv9WpPLKTGWv0Wq2SCKpL5OiJ3KPRJjT7ut680a8mrzv7d46m6rC
bCz4b/SVJ/H/sASWRYGHIvL2i6pXxCWoVICU125qEEPFvXxTcyvI/LvyRAhoNZua
fGKLFgwaL82WtD8/6lOLRC1iVEUmyv0YI4JuVh27TxSOKy3lXpow1omyUGi3LkPu
had+lmZFESYPjWl92o+W8MgnzA8JJkyV3opEyaEnuubPM9XqG+eNJs1muFenPFcq
B9kmKhpJM9wW6EXgIQLsc45IWE9lPYYMr6CM+O0rJn2mzB1z6XVT43uhYuugKYKu
dAO8EBgkiQqi+OP26QECAwEAAaNyMHAwHQYDVR0OBBYEFPUXQ7zeACfHkXSqOe0A
2o+gxvwbMEEGA1UdIwQ6MDiAFPUXQ7zeACfHkXSqOe0A2o+gxvwboRWkEzARMQ8w
DQYDVQQDEwZEYVJvb3SCCQDWrPl7rFQQcDAMBgNVHRMEBTADAQH/MA0GCSqGSIb3
DQEBDQUAA4IBAQB9Iq1uGRYA215HR/6Lmm6uJOeZaJGBb4FyZL4XlujbhE/yITNk
bRznsa1HGyqe/SqMuCnvjn55YsWiztex+X9pv4KALtQ/pASP5cv/HTF5Uz/qnEuV
5/n2EN+XYYl4IyF1CUF2DQayJgORtKL3t1izfpc5RFhwmEe7bZMSLo6uktSjdP09
PEFyx8SsrLOlfA574rg6GSIpBmHU4UxdEK2bSU60vbjmCt+SHqbkX10DhI63TLGB
qxVDWaaRPQKiQQrIirUBbhtspZz6HBOtrnj+u7wWAGT4q+Kq01zjNfxTbvaK8n2D
P7aqsLeDrZUApm9OYbf89AiFJQPuKO1BjUvF
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
