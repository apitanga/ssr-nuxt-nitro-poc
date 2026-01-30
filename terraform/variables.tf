# SSR Nuxt/Nitro PoC - Variables

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "dr_region" {
  description = "DR AWS region"
  type        = string
  default     = "us-west-2"
}

variable "domain_name" {
  description = "Base domain name"
  type        = string
  default     = "pitanga.org"
}

variable "subdomain" {
  description = "Subdomain for the application"
  type        = string
  default     = "ssr-poc"
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 10
}
