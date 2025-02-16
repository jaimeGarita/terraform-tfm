locals {
  region_alias  = var.region_alias
  region        = var.region
  environment   = var.environment
  business_unit = var.business_unit
  account_id    = var.account_id
  env = {
    vpc_name = "main"
  }
}

data "aws_vpc" "default" {
  default = true
}

# Obtener todas las subnets por defecto
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = ["${var.region}a", "${var.region}b", "${var.region}c"]
  }
}

locals {
  subnet_ids = data.aws_subnets.default.ids

  validate_subnet_count = length(local.subnet_ids) >= 2 ? true : tobool("Se requieren al menos 2 subnets para el grupo de subnets de DMS")
}

######### SG BEGIN #########

resource "aws_security_group" "dms_instance_sg" {
  name        = "${local.region_alias}-${local.environment}-${local.business_unit}-datalake-dms-sg"
  description = "SG for DMS Instance"
  vpc_id      = data.aws_vpc.default.id
}

# tfsec:ignore:aws-vpc-no-public-egress-sgr
resource "aws_security_group_rule" "egress" {
  type              = "egress"
  description       = "To Internet"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.dms_instance_sg.id
}

resource "aws_security_group_rule" "ingress_sg" {
  type                     = "ingress"
  security_group_id        = aws_security_group.dms_instance_sg.id
  description              = "Allow all traffic from SG"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.dms_instance_sg.id
}

resource "aws_security_group_rule" "ingress_vpc" {
  type              = "ingress"
  security_group_id = aws_security_group.dms_instance_sg.id
  description       = "Allow PSQL traffic from VPC"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.default.cidr_block]
}

######### SG FINISH #########

######### SBG BEGIN #########

data "aws_iam_policy_document" "dms_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["dms.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "dms_bu_vpc_role" {
  assume_role_policy = data.aws_iam_policy_document.dms_assume_role.json
  name               = "dms-bu-${local.business_unit}-vpc-role"
}

resource "aws_iam_role_policy_attachment" "dms_vps_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
  role       = aws_iam_role.dms_bu_vpc_role.name

  # It takes some time for these attachments to work, and creating the aws_dms_replication_subnet_group fails if this attachment hasn't completed.
  provisioner "local-exec" {
    command = "sleep 30"
  }
}

# Crear el rol dms-vpc-role requerido por DMS
resource "aws_iam_role" "dms_vpc_role" {
  name = "dms-vpc-role"  # Este nombre es requerido por DMS

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })
}

# Adjuntar la política necesaria al rol
resource "aws_iam_role_policy_attachment" "dms_vpc_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
  role       = aws_iam_role.dms_vpc_role.name
}

# Esperar a que el rol esté listo
resource "time_sleep" "wait_for_role" {
  depends_on = [aws_iam_role_policy_attachment.dms_vpc_role_policy]
  create_duration = "30s"
}

resource "aws_dms_replication_subnet_group" "datalake_dms_bu_subnet_group" {
  replication_subnet_group_description = "Subnet group for ${var.region_alias}-${var.environment}-${var.business_unit}-datalake-dms-bu-instance"
  replication_subnet_group_id          = "${var.region_alias}-${var.environment}-${var.business_unit}-datalake-dms-bu-subnet-group"
  subnet_ids                           = local.subnet_ids

  depends_on = [
    time_sleep.wait_for_role
  ]
}

######### SBG FINISH #########

######### DMS REP INSTANCE BEGIN #########

resource "aws_kms_key" "datalake_kms_key" {
  description = "Key to encrypt DMS instance"
}

resource "aws_dms_replication_instance" "datalake_dms_instance" {
  allocated_storage           = var.allocated_storage
  apply_immediately           = true
  auto_minor_version_upgrade  = false
  engine_version              = var.engine_version
  kms_key_arn                 = aws_kms_key.datalake_kms_key.arn
  multi_az                    = false
  publicly_accessible         = false
  replication_instance_class  = var.replication_instance_class
  allow_major_version_upgrade = true


  replication_instance_id     = "${local.region_alias}-${local.environment}-${local.business_unit}-datalake-dms-bu-instance"
  replication_subnet_group_id = aws_dms_replication_subnet_group.datalake_dms_bu_subnet_group.id

  vpc_security_group_ids = [
    aws_security_group.dms_instance_sg.id
  ]
}

######### DMS REP INSTANCE FINISH #########

resource "aws_iam_role" "cloudwatch_dms_bu" {
  name        = "dms-bu-${local.business_unit}-cloudwatch-logs-role"
  description = "Allow DMS to send logs to CloudWatch"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "dms.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dms_logs_cloudwatch" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
  role       = aws_iam_role.cloudwatch_dms_bu.id
}

resource "aws_iam_role" "kinesis_dms_bu" {
  name        = "${local.region_alias}-${local.environment}-${var.business_unit}-role-kinesis-dms-bu"
  description = "DMS and Kinesis Datalake Stream"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "dms.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      },
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "firehose.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

# tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_policy" "kinesis_dms_bu" {
  name        = "${local.region_alias}-${local.environment}-${local.business_unit}-policy-kinesis-dms-bu"
  description = "Associated policy for Kinesis of Datalake"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : ["kinesis:*"],
        "Resource" : [
          "arn:aws:kms:*:${local.account_id}:key/*",
          "arn:aws:kinesis:*:${local.account_id}:*/*/consumer/*:*",
          "arn:aws:kinesis:${local.region}:${local.account_id}:stream/*"
        ]
      },
      {
        "Sid" : "VisualEditor4",
        "Action" : [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ],
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:s3:::datalake-raw-s3-${local.account_id}",
          "arn:aws:s3:::datalake-raw-s3-${local.account_id}/*"
        ]
      },
    ]
  })
}


resource "aws_iam_role_policy_attachment" "kinesis_dms_bu_role" {
  policy_arn = aws_iam_policy.kinesis_dms_bu.arn
  role       = aws_iam_role.kinesis_dms_bu.id
}

resource "aws_iam_role" "dms_role" {
  name = "${local.region_alias}-${local.environment}-${local.business_unit}-dms-bu-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "dms.${local.region}.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

# AWS built in policies

resource "aws_iam_policy" "secrets_manager_read_only" {
  name        = "${local.region_alias}-${local.environment}-${local.business_unit}-datalake-secrets-readonly-iam-policy"
  description = "Policy to access db credentials from datalake resources"
  policy = jsonencode({
    "Statement" : [
      {
        "Action" : [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds",
          "secretsmanager:ListSecrets"
        ],
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:kubernetes/*-credentials-*"
        ]
      }
    ],
    "Version" : "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "ssm_access" {
  policy_arn = aws_iam_policy.secrets_manager_read_only.arn
  role       = aws_iam_role.kinesis_dms_bu.id
}

resource "aws_iam_role_policy_attachment" "dms_ssm_access" {
  policy_arn = aws_iam_policy.secrets_manager_read_only.arn
  role       = aws_iam_role.dms_role.id
}

resource "aws_iam_role_policy_attachment" "rds_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
  role       = aws_iam_role.dms_role.id
}

resource "aws_iam_role_policy_attachment" "dms_readshift_access" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSRedshiftS3Role"
  role       = aws_iam_role.dms_role.id
}

resource "aws_iam_role_policy_attachment" "dms_migration_hub_access" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSMigrationHubDMSAccess"
  role       = aws_iam_role.dms_role.id
}

resource "aws_iam_role_policy_attachment" "cloudwatch_access" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsReadOnlyAccess"
  role       = aws_iam_role.dms_role.id
}

resource "aws_iam_role_policy_attachment" "dms_cloudwatch_access" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
  role       = aws_iam_role.dms_role.id
}

resource "aws_iam_role_policy_attachment" "dms_vpc_access" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
  role       = aws_iam_role.dms_role.id
}


# # EMR EC2 Default role policies

# resource "aws_iam_instance_profile" "emr_ec2_instance_profile" {
#   name = "EMR_EC2_DefaultRole"
#   role = "EMR_EC2_DefaultRole"
#   tags = {
#     Repository   = "static-infra"
#     Environment  = "infra"
#     Application  = "datalake"
#     Compliance   = "None"
#     Tenant       = "shared"
#     BusinessUnit = "data"
#     Region       = "use1"
#     Geography    = "global"
#     Team         = "data"
#     Purpose      = "datalake"
#     Monitoring   = "true"
#     Provisioned  = "terraform"
#   }
# }

# resource "aws_iam_role_policy_attachment" "emc_ec2_role_kinesis_access" {
#   policy_arn = aws_iam_policy.kinesis.arn
#   role       = "EMR_EC2_DefaultRole"
# }

# resource "aws_iam_role_policy_attachment" "emc_ec2_role_ssm_instance" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
#   role       = "EMR_EC2_DefaultRole"
# }

# resource "aws_iam_role_policy_attachment" "emc_elastic_map_reduce_for_ec2_role" {
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
#   role       = "EMR_EC2_DefaultRole"
# }

output "dms_security_group_id" {
  description = "ID del security group de DMS"
  value       = aws_security_group.dms_instance_sg.id
}

# # VPC Endpoint para Kinesis
# resource "aws_vpc_endpoint" "kinesis" {
#   vpc_id             = data.aws_vpc.default.id
#   service_name       = "com.amazonaws.${var.region}.kinesis-streams"
#   vpc_endpoint_type  = "Interface"
  
#   # Usar las subnets disponibles excluyendo us-west-2d
#   subnet_ids = local.subnet_ids

#   security_group_ids = [aws_security_group.dms_instance_sg.id]

#   private_dns_enabled = true

#   tags = {
#     Name           = "${local.region_alias}-${local.environment}-${local.business_unit}-kinesis-endpoint"
#     Environment    = local.environment
#     BusinessUnit   = local.business_unit
#   }
# }
