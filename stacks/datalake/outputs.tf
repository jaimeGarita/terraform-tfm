output "bucket_name" {
  description = "El nombre del bucket S3 creado para el datalake"
  value       = module.datalake_s3.bucket_name
}

# output "role_name" {
#   description = "El nombre del rol IAM creado para el crawler del datalake"
#   value       = module.datalake_role.role_name
# }
#
# output "glue_database_name" {
#   description = "El nombre de la base de datos de Glue creada para el datalake"
#   value       = module.glue_athena.glue_database_name
# }
#
# output "athena_workgroup_name" {
#   description = "El nombre del grupo de trabajo de Athena creado"
#   value       = module.glue_athena.athena_workgroup_name
# }
