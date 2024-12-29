provider "aws" {
  region = "us-east-1"
}

module "datalake_s3" {
  source      = "../modules/s3_bucket"
  bucket_name = var.bucket_name
  acl         = "private"
}

module "datalake_role" {
  source    = "../modules/iam_role"
  role_name = var.role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

# module "glue_athena" {
#   source            = "../modules/glue_athena"
#   bucket_name       = var.bucket_name
#   glue_database_name = var.glue_database_name
#   athena_workgroup_name = var.athena_workgroup_name
# }
