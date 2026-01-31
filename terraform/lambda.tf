# Lambda Functions for SSR - Primary and DR regions

# Primary Region Lambda
module "lambda_primary" {
  source = "./modules/lambda"
  
  providers = {
    aws = aws.primary
  }

  function_name     = "${local.app_name}-primary"
  description       = "SSR Nuxt/Nitro app - Primary Region"
  memory_size       = var.lambda_memory_size
  timeout           = var.lambda_timeout
  s3_bucket         = aws_s3_bucket.lambda_deployments_primary.id
  s3_key            = "lambda/nitro-ssr.zip"
  environment_variables = local.lambda_environment
  
  tags = local.common_tags
}

# DR Region Lambda
module "lambda_dr" {
  source = "./modules/lambda"
  
  providers = {
    aws = aws.dr
  }

  function_name     = "${local.app_name}-dr"
  description       = "SSR Nuxt/Nitro app - DR Region"
  memory_size       = var.lambda_memory_size
  timeout           = var.lambda_timeout
  s3_bucket         = aws_s3_bucket.lambda_deployments_dr.id
  s3_key            = "lambda/nitro-ssr.zip"
  environment_variables = local.lambda_environment
  
  tags = local.common_tags
}

# Lambda environment variables (common to both regions)
locals {
  lambda_environment = {
    NODE_ENV        = "production"
    NITRO_PRESET    = "aws-lambda"
    DYNAMODB_TABLE  = aws_dynamodb_table.visits_primary.name
    PRIMARY_REGION  = var.primary_region
    DR_REGION       = var.dr_region
  }
}

# IAM Role for Lambda execution
resource "aws_iam_role" "lambda_execution" {
  provider = aws.primary
  name     = "${local.app_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

# IAM Policy for DynamoDB access
resource "aws_iam_policy" "lambda_dynamodb" {
  provider = aws.primary
  name     = "${local.app_name}-dynamodb-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.visits_primary.arn,
          "${aws_dynamodb_table.visits_primary.arn}/*"
        ]
      }
    ]
  })
}

# Attach policies to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  provider   = aws.primary
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  provider   = aws.primary
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_dynamodb.arn
}

# Lambda Function URL for primary region
resource "aws_lambda_function_url" "primary" {
  provider           = aws.primary
  function_name      = module.lambda_primary.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["*"]
    max_age          = 86400
  }
}

# Lambda Function URL for DR region
resource "aws_lambda_function_url" "dr" {
  provider           = aws.dr
  function_name      = module.lambda_dr.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["*"]
    max_age          = 86400
  }
}
