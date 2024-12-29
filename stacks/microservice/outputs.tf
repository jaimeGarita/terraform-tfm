output "bucket_name" {
  description = "El nombre del bucket S3 creado para el datalake"
  value       = module.microservice_s3.bucket_name
}

output "role_name" {
  description = "El nombre del rol IAM creado para el microservicio"
  value       = module.microservice_role.role_name
}
