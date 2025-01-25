resource "aws_s3_bucket" "datalake" {
  bucket = "${var.service}-${var.environment}-${var.region_alias}-datalake"

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "datalake" {
  bucket = aws_s3_bucket.datalake.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "datalake_raw_lifecycle" {
  bucket = aws_s3_bucket.datalake.id

  rule {
    id     = "delete_old_files"
    status = "Enabled"

    expiration {
      days = 7
    }
  }
}

