variable "bucket_name" {
  description = "El nombre del bucket S3 que usará Glue y Athena"
  type        = string
}

variable "glue_database_name" {
  description = "El nombre de la base de datos de Glue"
  type        = string
  default     = "datalake_db"
}

variable "athena_workgroup_name" {
  description = "El nombre del grupo de trabajo de Athena"
  type        = string
  default     = "primary"
}
