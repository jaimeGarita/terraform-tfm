resource "aws_iam_role" "kinesis-firehose-delivery-iam-role" {
  name = "${var.region_alias}-${var.environment}-data-${var.service}-firehose"
  path = "/"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service : "dms.amazonaws.com"
        },
        Effect = "Allow",
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "firehose.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "firehose.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
  tags = aws_kinesis_stream.kinesis-endpoint.tags
}

resource "aws_iam_role_policy" "kinesis-firehose-delivery-policy" {
  name = "${var.region_alias}-${var.environment}-data-${var.service}-firehose-s3-access"
  role = aws_iam_role.kinesis-firehose-delivery-iam-role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ],
        Resource = [
          local.s3_destiny_bucket,
          "${local.s3_destiny_bucket}/*"
        ],
        Effect = "Allow"
      },
      {
        Effect = "Allow",
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards",
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ],
        Resource = aws_kinesis_stream.kinesis-endpoint.arn
      }
    ]
  })
}