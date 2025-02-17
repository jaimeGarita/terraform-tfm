# GENERAL

# data "aws_subnet" "subnets" {
#   for_each = toset(data.terraform_remote_state.networking.outputs.subnets_ids)
#   id       = each.value
# }

variable "region" {
  description = "AWS region"
  type        = string
}

variable "region_alias" {
  description = "Alias for the AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "business_unit" {
  description = "Business unit name"
  type        = string
}

variable "account_id" {
  type        = string
  description = "Account ID"
}

# DMS

variable "engine_version" {
  type    = string
  default = "3.5.2"
}

variable "replication_instance_class" {
  type        = string
  description = "Replication instance class"
  default     = "dms.t3.micro"
}

variable "allocated_storage" {
  type        = number
  default     = 20
  description = "Allocated Storage GB"
}

variable "vpc_id" {
  description = "ID of the VPC where DMS will be deployed"
  type        = string
  default     = null  # Si se deja en null, usará la VPC por defecto
}