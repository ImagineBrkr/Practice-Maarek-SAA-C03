#Buckets

resource "aws_s3_bucket" "s3_bucket_web_server" {
  #Must be a unique name
  bucket = "my-web-server-objects-112233"
}

#We can upload objects to the bucket
resource "aws_s3_object" "s3_object_image" {
  bucket = aws_s3_bucket.s3_bucket_web_server.bucket
  key    = "images/images1.jpg"
  source = "image1.jpg"
  acl    = "private"
}


# Bucket Security


# We can block ALL public access to prevent data leak
# With this on, no policy will allow public access to the bucket
resource "aws_s3_bucket_public_access_block" "s3_bucket_web_server_block_access" {
  bucket = aws_s3_bucket.s3_bucket_web_server.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

#Now we allow public access with a bucket policy
resource "aws_s3_bucket_policy" "s3_bucket_policy_allow_public_access" {
  bucket = aws_s3_bucket.s3_bucket_web_server.id
  policy = <<EOT
{
"Version": "2012-10-17",
"Statement": [
    {
      "Sid": "Allow Public Access",
      "Action": "s3:GetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Resource": "${aws_s3_bucket.s3_bucket_web_server.arn}/*"
    }
  ]
}
EOT
}


#S3 Websites


# We can create a static website using an S3 bucket (must be publicly accesible)
resource "aws_s3_bucket_website_configuration" "s3_static_website" {
  bucket = aws_s3_bucket.s3_bucket_web_server.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

  routing_rule {
    condition {
      key_prefix_equals = "docs/"
    }
    redirect {
      replace_key_prefix_with = "documents/"
    }
  }
}


# S3 Versioning


# You can activate versioning in a bucket
# Every object inserted after this will have version control.
resource "aws_s3_bucket_versioning" "s3_bucket_web_server_versioning" {
  bucket = aws_s3_bucket.s3_bucket_web_server.id
  versioning_configuration {
    status = "Enabled"
  }
}