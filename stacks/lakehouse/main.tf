module "rds_to_datalake" {
  source = "../../modules/rds_to_datalake"

  region                    = "us-east-1"
  region_alias             = "use1"
  environment              = "prod"
  service                  = "lakehouse"
  business_unit            = "data"
  account_id               = "337909753078"
  cluster                  = "your-rds-cluster-name"
  database_name            = "your-database-name"
  secrets_manager_arn      = "arn:aws:secretsmanager:us-east-1:YOUR_ACCOUNT_ID:secret:your-secret-name"
  replication_instance_arn = "arn:aws:dms:us-east-1:YOUR_ACCOUNT_ID:rep:your-replication-instance"
  compliance              = "pci"
  vpc_id                  = "your-vpc-id"
  
  tags = {
    Environment = "prod"
    Project     = "lakehouse"
  }
} 