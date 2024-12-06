# DynamoDB Table

resource "aws_dynamodb_table" "ddb_table_game_server" {
  name           = "GameScores"
  billing_mode   = "PROVISIONED" # We specify the capacity
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "UserId"
  range_key      = "GameTitle"
  server_side_encryption {
    enabled = true
    # kms_key_arn = "keay_arn"   # We can use our key or a key managed by DynamoDB
  }


  attribute {
    name = "UserId"
    type = "S"
  }

  attribute {
    name = "GameTitle"
    type = "S"
  }

  ttl {
    attribute_name = "TimeToExist"
    enabled        = true
  }
}