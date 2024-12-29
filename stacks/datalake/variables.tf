variable "bucket_name" {
  description = "El nombre del bucket S3 para el datalake"
  type        = string
  default     = "use1-data-datalake-s3"
}

variable "role_name" {
  description = "El nombre del rol IAM para el crawler del datalake"
  type        = string
  default     = "crawler-role"
}

variable "glue_database_name" {
  description = "El nombre de la base de datos en Glue"
  type        = string
  default     = "datalake_db"
}

variable "athena_workgroup_name" {
  description = "El nombre del grupo de trabajo de Athena"
  type        = string
  default     = "primary"
}
