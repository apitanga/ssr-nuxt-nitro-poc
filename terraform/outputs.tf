# SSR Nuxt/Nitro PoC - Outputs

# Application Outputs
output "cloudfront_domain" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "primary_lambda_function_name" {
  description = "Primary region Lambda function name"
  value       = module.lambda_primary.function_name
}

output "dr_lambda_function_name" {
  description = "DR region Lambda function name"
  value       = module.lambda_dr.function_name
}

output "dynamodb_table_name" {
  description = "DynamoDB Global Table name"
  value       = aws_dynamodb_global_table.visits.name
}

output "application_url" {
  description = "Application URL"
  value       = "https://${var.subdomain}.${var.domain_name}"
}

# CI/CD Outputs
output "cicd_user_name" {
  description = "Name of the CI/CD IAM user"
  value       = aws_iam_user.cicd.name
}

output "cicd_user_arn" {
  description = "ARN of the CI/CD IAM user"
  value       = aws_iam_user.cicd.arn
}

output "cicd_credentials_secret" {
  description = "AWS Secrets Manager ARN containing CI/CD credentials"
  value       = aws_secretsmanager_secret.cicd_credentials.arn
}
