variable "region" {
  type        = string
  description = "Full name of the region"
}

variable "environment" {
  type    = string
  default = "infra"
}

variable "region_alias" {
  description = "Short name for the AWS region, to be used as a component of resource names."
  type        = string
}

variable "service" {
  description = "Name of the service"
  type        = string
}

variable "business_unit" {
  description = "Name of the business unit. It will be used as a component of resource names."
  type        = string
}

variable "account_id" {
  description = "The AWS account ID"
  type        = string
}

variable "cluster" {
  description = "The name of the RDS cluster"
  type        = string
}

variable "database_name" {
  description = "The name of the database"
  type        = string
}

variable "secrets_manager_arn" {
  description = "The ARN of the secret to access the RDS database"
  type        = string
}

variable "replication_instance_arn" {
  description = "The ARN of the DMS replication instance"
  type        = string
}

variable "purpose" {
  type    = string
  default = "datalake"
}

variable "compliance" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "cluster_endpoint" {
  description = "The endpoint hostname of the RDS cluster"
  type        = string
}

provider "aws" {
  region = "us-west-2"
  alias  = "us-west-2"
  default_tags {
    tags = {
      Application  = var.service
      Team         = "data"
      BusinessUnit = "data-fraud"
      Compliance   = var.compliance
      Environment  = var.environment
      Monitoring   = "true"
      Provisioned  = "terraform"
      Region       = var.region
      Geography    = "global"
      Repository   = "static-infra"
      Tenant       = "shared"
    }
  }
}
