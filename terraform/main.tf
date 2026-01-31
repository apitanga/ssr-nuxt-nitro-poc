# SSR Nuxt/Nitro PoC - Main Terraform Configuration
# Multi-region serverless SSR with CloudFront failover
# Terraform Cloud backend for remote state and execution

terraform {
  required_version = ">= 1.5.0"

  cloud {
    organization = "Pitangaville"
    
    workspaces {
      name = "ssr-nuxt-nitro-poc"
    }
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws.primary, aws.dr]
    }
  }
}

# Primary Region Provider (us-east-1)
provider "aws" {
  alias  = "primary"
  region = var.primary_region
  
  default_tags {
    tags = local.common_tags
  }
}

# DR Region Provider (us-west-2)
provider "aws" {
  alias  = "dr"
  region = var.dr_region
  
  default_tags {
    tags = local.common_tags
  }
}

# Local values
locals {
  common_tags = {
    Project     = "ssr-nuxt-nitro-poc"
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = "andre.pitanga@fiserv.com"
  }
  
  app_name = "ssr-poc"
  domains = {
    primary = "${var.subdomain}.${var.domain_name}"
  }
}

# Data sources
data "aws_caller_identity" "current" {
  provider = aws.primary
}

data "aws_region" "primary" {
  provider = aws.primary
}

data "aws_region" "dr" {
  provider = aws.dr
}
