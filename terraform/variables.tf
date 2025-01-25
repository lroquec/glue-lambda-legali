variable "region" {
  description = "The region in which the resources will be created"
  default     = "us-east-1"
  
}

# Variables
variable "environment" {
  type        = string
  description = "Environment name (e.g. dev, prod)"
  default = "prod"
}