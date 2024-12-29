provider "aws" {
  region = "us-east-1"
}

module "microservice_s3" {
  source      = "../modules/s3_bucket"
  bucket_name = var.bucket_name
  acl         = "private"
}

module "microservice_role" {
  source        = "../modules/iam_role"
  role_name     = var.role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
      }
    ]
  })
}
