# Symmetric key

resource "aws_kms_key" "kms_master_key" {
  description             = "Master symmetric encryption KMS key"
  key_usage               = "ENCRYPT_DECRYPT"
  enable_key_rotation     = true
  deletion_window_in_days = 20
}

resource "aws_kms_alias" "kms_master_key_alias" {
  name          = "alias/master-key"
  target_key_id = aws_kms_key.kms_master_key.key_id
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key_policy" "kms_master_key_policy" {
  key_id = aws_kms_key.kms_master_key.id
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-default-1"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}


# SSM Parameters


resource "aws_ssm_parameter" "ssm_parameter_web_server_dev_db_url" {
  name        = "/web-server/dev/db-url"
  description = "DB URL for the dev environment for the web server"
  type        = "String"
  value       = "web-server.db.dev.internal"
}

resource "aws_ssm_parameter" "ssm_parameter_web_server_dev_db_password" {
  name        = "/web-server/dev/db-url"
  description = "DB URL for the dev environment for the web server"
  type        = "SecureString"
  value       = var.db_password
  tier        = "Standard"
  key_id      = aws_kms_alias.kms_master_key_alias.name
}


# Secrets Manager


resource "aws_secretsmanager_secret" "secret_apig_key" {
  name = "apig-key"
}

resource "aws_secretsmanager_secret_version" "secret_apig_key_value" {
  secret_id     = aws_secretsmanager_secret.secret_apig_key.id
  secret_string = var.apig_key
}