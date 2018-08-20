require "chef/provisioning/aws_driver"
with_driver "aws"

aws_s3_bucket "aws-bucket" do
  enable_website_hosting true
  website_options index_document: {
    suffix: "index.html"
  },
                  error_document: {
                    key: "not_found.html"
                  }
end
