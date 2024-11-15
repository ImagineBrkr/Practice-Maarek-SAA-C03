## USER CREATION


# Create an user
resource "aws_iam_user" "iam_user_stephan" {
  name          = "Stephan-Rodriguez"
  path          = "/" #Default "/""
  force_destroy = true
}

#Create a password for the user
resource "aws_iam_user_login_profile" "iam_user_stephan_create_password" {
  user = aws_iam_user.iam_user_stephan.name
  # pgp_key = "keybase:some_person_that_exists"
  password_length         = 20
  password_reset_required = true
}

output "iam_user_stephan_password" {
  # In plain text if not enctrypted by pgp_key
  value = aws_iam_user_login_profile.iam_user_stephan_create_password.password
  # Or encrypted in base64
  # value = aws_iam_user_login_profile.iam_user_stephan_create_password.encrypted_password
  sensitive = true
}


## USER GROUP CREATION


# Create an IAM Group
resource "aws_iam_group" "iam_group_developers" {
  name = "developers"
  path = "/"
}

# Create an IAM Group
resource "aws_iam_group" "iam_group_db_administrator" {
  name = "db_administrator"
  path = "/"
}

# Add the user to one or multiple groups
# The user will inherit the permissions from every group
resource "aws_iam_user_group_membership" "iam_user_stephan_groups" {
  user = aws_iam_user.iam_user_stephan.name

  groups = [
    aws_iam_group.iam_group_developers.name,
    aws_iam_group.iam_group_db_administrator.name
  ]
}


## POLICY CREATION


resource "aws_iam_policy" "iam_policy_development" {
  name        = "development_policy"
  path        = "/"
  description = "Policy with permissions required for development"

  # The policy is a json document
  # The ID is optional
  # The Sid (Statement Id) is optional
  policy = <<EOT
{
  "Version": "2012-10-17",
  "Id": "Development-Permissions",
  "Statement": [
    {
      "Sid": "1",
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Sid": "2",
      "Action": [
        "s3:Get*",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOT
}

resource "aws_iam_policy" "iam_policy_db_administrator" {
  name        = "db_administrator_policy"
  path        = "/"
  description = "Policy with permissions required for database administrators"

  policy = <<EOT
{
  "Version": "2012-10-17",
  "Id": "DB-Administrator-Permissions",
  "Statement": [
    {
      "Sid": "1",
      "Action": [
        "rds:Describe*",
        "rds:Create*",
        "rds:Delete*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOT
}

# Attach policy to group

resource "aws_iam_group_policy_attachment" "iam_group_attach_policy_developers" {
  group      = aws_iam_group.iam_group_developers.name
  policy_arn = aws_iam_policy.iam_policy_development.arn
}

resource "aws_iam_group_policy_attachment" "iam_group_attach_policy_db_administrators" {
  group      = aws_iam_group.iam_group_db_administrator.name
  policy_arn = aws_iam_policy.iam_policy_development.arn
}

# You can directly add permissions to an user, though it's not recommended
# resource "aws_iam_user_policy_attachment" "iam_user_attach_policy_more_permissions" {
#   user       = aws_iam_user.iam_user_stephan.name
#   policy_arn = aws_iam_policy.iam_policy_more_permissions.arn
# }


## PERMISSSIONS BOUNDARY


# You can add a permissions boundary to an user
# https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html
# This will limit the permissions that an user can inherit from any source (groups or policies)

resource "aws_iam_policy" "iam_policy_boundary_for_user" {
  name        = "boundary_policy"
  path        = "/"
  description = "Policy with the permissions boundary for new users"

  policy = <<EOT
{
  "Version": "2012-10-17",
  "Id": "Boundary-Permissions",
  "Statement": [
    {
      "Sid": "1",
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "cloudwatch:*",
        "ec2:*"
      ],
      "Resource": "*"
    }
  ]
}
EOT
}

resource "aws_iam_user" "iam_user_mary" {
  name                 = "Mary-Pelaez"
  path                 = "/"
  force_destroy        = true
  permissions_boundary = aws_iam_policy.iam_policy_boundary_for_user.arn
  # Even though the policy says Allow, it doesn't give any permissions
}


## PASSWORD POLICY


# Password policy for all the users on the account
# https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_passwords_account-policy.html
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length      = 8
  require_lowercase_characters = true
  require_numbers              = true
  require_uppercase_characters = true
  require_symbols              = true

  allow_users_to_change_password = true
  password_reuse_prevention      = true
  max_password_age               = 30
  hard_expiry                    = false
}


## IAM ROLES


resource "aws_iam_role" "iam_role_ec2" {
  name = "ec2_role"
  path = "/"
  # It can also have permissions boundary
  # permissions_boundary = aws_iam_policy.iam_policy_boundary_for_user.arn

  # The assume role policy specifies which service will use this role
  # It can also specify other accounts
  assume_role_policy = <<EOT
"Version": "2012-10-17",
"Statement": [
    {
      "Action": "sts:AssumeRole"
      "Effect": "Allow"
      "Sid": "1"
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ]
}
EOT
}

# Now we give permissions to the role
resource "aws_iam_role_policy_attachment" "iam_role_policy_attach_development" {
  role       = aws_iam_role.iam_role_ec2.name
  policy_arn = aws_iam_policy.iam_policy_development.arn
}