locals {
  s3_destiny_bucket = "arn:aws:s3:::datalake-raw-s3-${var.account_id}"
}

resource "aws_kinesis_stream" "kinesis-endpoint" {
  name             = "${var.region_alias}-${var.environment}-data-${var.service}-endpoint"
  retention_period = 24
  shard_count      = 2
}

resource "aws_kinesis_firehose_delivery_stream" "kinesis-firehose" {
  name = "${var.region_alias}-${var.environment}-data-${var.service}-rds"
  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.kinesis-endpoint.arn
    role_arn           = aws_iam_role.kinesis-firehose-delivery-iam-role.arn
  }
  extended_s3_configuration {
    bucket_arn          = local.s3_destiny_bucket
    compression_format  = "HADOOP_SNAPPY"
    prefix              = "firehose/rds/${var.cluster}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    role_arn            = aws_iam_role.kinesis-firehose-delivery-iam-role.arn
    error_output_prefix = "firehose_error/rds/${var.cluster}/result=!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
  }
  destination = "extended_s3"
}

output "kinesis-stream-arn" {
  value = aws_kinesis_stream.kinesis-endpoint.arn
}

output "kinesis-firehose-arn" {
  value = aws_kinesis_firehose_delivery_stream.kinesis-firehose.arn
}
