# SSR Nuxt/Nitro PoC - Outputs

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
