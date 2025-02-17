output "replication_instance_arn" {
  description = "ARN of the DMS replication instance"
  value       = aws_dms_replication_instance.datalake_dms_instance.replication_instance_arn
} 