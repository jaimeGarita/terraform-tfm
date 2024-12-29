variable "bucket_name" {
  description = "El nombre del bucket S3 para el microservicio"
  type        = string
  default     = "use1-data-microservice-s3"
}

variable "role_name" {
  description = "El nombre del rol IAM para el microservicio"
  type        = string
  default     = "use1-app-role"
}
