# DynamoDB Global Table for visit counter and session data

# Primary region table
resource "aws_dynamodb_table" "visits_primary" {
  provider       = aws.primary
  name           = "${local.app_name}-visits"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "PK"
  range_key      = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  tags = local.common_tags
}

# Global Table replication
resource "aws_dynamodb_global_table" "visits" {
  provider = aws.primary
  name     = "${local.app_name}-visits"

  replica {
    region_name = var.primary_region
  }

  replica {
    region_name = var.dr_region
  }

  depends_on = [aws_dynamodb_table.visits_primary]
}

# Initial counter item
resource "aws_dynamodb_table_item" "counter" {
  provider   = aws.primary
  table_name = aws_dynamodb_table.visits_primary.name
  hash_key   = "PK"
  range_key  = "SK"

  item = jsonencode({
    PK = { S = "GLOBAL" }
    SK = { S = "COUNTER" }
    count = { N = "0" }
  })
}
