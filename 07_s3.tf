#Buckets

resource "aws_s3_bucket" "s3_bucket_web_server" {
  #Must be a unique name
  bucket = "my-web-server-objects-112233"
}

#We can upload objects to the bucket
resource "aws_s3_object" "s3_object_image" {
  bucket        = aws_s3_bucket.s3_bucket_web_server.bucket
  key           = "images/images1.jpg"
  source        = "image1.jpg"
  acl           = "private"
  storage_class = "INTELLIGENT_TIERING" #Automatically move between tiers.
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


# Event Notification


# We create an SNS topic with a policy that gives permissions to S3 to send events.
data "aws_iam_policy_document" "sns_s3_events_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["SNS:Publish"]
    resources = ["arn:aws:sns:*:*:s3-event-notification-topic"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.s3_bucket_web_server.arn]
    }
  }
}
resource "aws_sns_topic" "sns_topic_s3_events" {
  name   = "s3-event-notification-topic"
  policy = data.aws_iam_policy_document.sns_s3_events_policy.json
}

resource "aws_s3_bucket_notification" "s3_event_notification_sns" {
  bucket = aws_s3_bucket.s3_bucket_web_server.id

  topic {
    topic_arn     = aws_sns_topic.sns_topic_s3_events.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".log"
  }
}


# Encryption


# We will use Server Side Encryption by default for every object
resource "aws_s3_bucket_server_side_encryption_configuration" "s3_bucket_web_server_encryption" {
  bucket = aws_s3_bucket.s3_bucket_web_server.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" #This will use SSE-S3 encryption
    }
  }
}

#You can encrypt an object with KMS keys

resource "aws_kms_key" "personal_kms_key" {
  description             = "KMS key Personal"
  deletion_window_in_days = 7
}

resource "aws_s3_object" "s3_object_image2" {
  key        = "index.jpg"
  bucket     = aws_s3_bucket.s3_bucket_web_server.id
  source     = "index.jpg"
  kms_key_id = aws_kms_key.personal_kms_key.arn
}


# CORS Configuration


#CORS Rules for http requests to the S3 Bucket
resource "aws_s3_bucket_cors_configuration" "s3_bucket_web_server_cors_conf" {
  bucket = aws_s3_bucket.s3_bucket_web_server.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }

  cors_rule {
    allowed_methods = ["POST"]
    allowed_origins = ["https://my-server.com"]
  }
}