# # outputs.tf

# output "pipeline_name" {
#   description = "Nombre del pipeline de CodePipeline"
#   value       = aws_codepipeline.pipeline.name
# }

# output "ecr_repository_url" {
#   description = "URL del repositorio de ECR"
#   value       = aws_ecr_repository.app_repo.repository_url
# }

# output "aws_s3_bucket" {
#   description = "Nombre del bucket S3 utilizado por el pipeline"
#   value       = aws_s3_bucket.pipeline_bucket.bucket
# }