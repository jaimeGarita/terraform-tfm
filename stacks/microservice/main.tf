variable "aws_account_id" {
  description = "ID de la cuenta AWS donde se desplegará la infraestructura"
  type        = string
}

provider "aws" {
  region = "us-west-2"
}
resource "aws_ecr_repository" "simple_docker_service" {
  name = "simple-docker-service"  # Nombre del repositorio en ECR

  image_tag_mutability = "MUTABLE"  # Permite sobrescribir etiquetas de imágenes

  image_scanning_configuration {
    scan_on_push = true  # Escanea la imagen en busca de vulnerabilidades al subirla
  }

  tags = {
    Environment = "Production"
  }
}

resource "aws_iam_role" "new_codepipeline_role" {
  name = "GabiotaRM"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
        Effect    = "Allow"
        Sid       = ""
      },
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Effect    = "Allow"
        Sid       = ""
      }
    ]
  })
}

resource "aws_iam_policy" "codepipeline_permissions" {
  name        = "CodePipelinePermissionsForBuild"
  description = "Allow CodePipeline to interact with CodeBuild, CodeStarConnections, and S3"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "codepipeline:*",
          "ecr:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = [
          "codebuild:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = [
          "s3:*"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.artifact_store.arn}",
          "${aws_s3_bucket.artifact_store.arn}/*"
        ]
      },
      {
        Action   = [
          "codestar-connections:UseConnection",
          "codestar-connections:ListConnections",
          "codestar-connections:GetConnection",
          "codestar-connections:PassConnection"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:codestar-connections:us-west-2:${var.aws_account_id}:connection/*"
      }
    ]
  })
}

resource "aws_iam_policy" "codebuild_permissions" {
  name        = "CodeBuildPermissions"
  description = "Permissions for CodeBuild to interact with other AWS services"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.artifact_store.arn}",
          "${aws_s3_bucket.artifact_store.arn}/*"
        ]
      },
      {
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "ec2:*",
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "attach_codebuild_permissions" {
  policy_arn = aws_iam_policy.codebuild_permissions.arn
  role       = aws_iam_role.new_codepipeline_role.name
}

resource "aws_iam_role_policy_attachment" "attach_codepipeline_permissions" {
  policy_arn = aws_iam_policy.codepipeline_permissions.arn
  role       = aws_iam_role.new_codepipeline_role.name
}

resource "aws_codebuild_project" "simple_docker_service_build" {
  name          = "SimpleDockerService"
  description   = "CodeBuild project for building and deploying the SimpleDockerService"
  service_role  = aws_iam_role.new_codepipeline_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  
    environment_variable {
      name  = "REPOSITORY_URI"
      value = "${var.aws_account_id}.dkr.ecr.us-west-2.amazonaws.com/simple-docker-service"
    }

    environment_variable {
      name  = "EC2_IP"
      value = aws_instance.ec2_instance.public_ip
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/jaimeGarita/api-tfm.git"
    git_clone_depth = 1

    buildspec = <<-EOF
      version: 0.2
      phases:
        pre_build:
          commands:
            - echo "Configurando AWS CLI..."
            - aws --version
            - echo "Intentando autenticación con ECR..."
            - aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${var.aws_account_id}.dkr.ecr.us-west-2.amazonaws.com
            - echo "Verificando REPOSITORY_URI..."
            - echo $REPOSITORY_URI
        build:
          commands:
            - echo "Building Docker image..."
            - docker build -t $REPOSITORY_URI:latest .
        post_build:
          commands:
            - echo "Pushing Docker image..."
            - docker push $REPOSITORY_URI:latest
            - echo "Esperando que la instancia EC2 esté lista..."
            - |
              until aws ec2 describe-instance-status --instance-ids ${aws_instance.ec2_instance.id} --query 'InstanceStatuses[0].SystemStatus.Status' --output text | grep -q "ok"; do
                sleep 10
                echo "Esperando que el sistema esté listo..."
              done
            - echo "Deploying to EC2..."
            - |
              aws ssm send-command \
                --region us-west-2 \
                --instance-ids ${aws_instance.ec2_instance.id} \
                --document-name "AWS-RunShellScript" \
                --comment "Deploy latest docker image" \
                --parameters commands=['
                  "aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin '$REPOSITORY_URI'",
                  "docker pull '$REPOSITORY_URI':latest",
                  "docker stop app || true",
                  "docker rm app || true",
                  "docker run -d --name app -p 5000:5000 '$REPOSITORY_URI':latest"
                ']
      EOF
  }

  source_version = "main"

  tags = {
    Environment = "Production"
  }
}

resource "aws_codepipeline" "my_pipeline" {
  name           = "SimpleDockerService"
  execution_mode = "QUEUED"
  pipeline_type  = "V2"
  role_arn       = aws_iam_role.new_codepipeline_role.arn
  tags           = {}
  tags_all       = {}

  artifact_store {
    location = aws_s3_bucket.artifact_store.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      category = "Source"
      configuration = {
        "Owner"      = "jaimeGarita"
        "Repo"       = "api-tfm"
        "Branch"     = "main"
        "OAuthToken" = "TOKEN"
      }
      input_artifacts  = []
      name             = "GitHub_Source"
      output_artifacts = ["SourceOutput"]
      owner            = "ThirdParty"
      provider         = "GitHub"
      run_order        = 1
      version          = "1"
    }
  }

  stage {
    name = "Build_and_Deploy"

    action {
      category = "Build"
      configuration = {
        "ProjectName" = aws_codebuild_project.simple_docker_service_build.name
      }
      input_artifacts  = ["SourceOutput"]
      name             = "Build_and_Deploy_to_EC2"
      output_artifacts = ["BuildOutput"]
      owner            = "AWS"
      provider         = "CodeBuild"
      run_order        = 1
      version          = "1"
    }
  }
}

resource "aws_iam_role" "ec2_ecr_role" {
  name = "EC2ECRRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ec2_ecr_policy" {
  name        = "EC2ECRPolicy"
  description = "Policy to allow EC2 to pull images from ECR and receive SSM commands"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssm:UpdateInstanceStatus",
          "ssm:GetDocument",
          "ssm:SendConfigurationInventory",
          "ssm:ListInstanceAssociations",
          "ssm:DescribeAssociation",
          "ssm:GetParameters"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ec2_ecr_policy" {
  policy_arn = aws_iam_policy.ec2_ecr_policy.arn
  role       = aws_iam_role.ec2_ecr_role.name
}

resource "aws_iam_instance_profile" "ec2_ecr_profile" {
  name = "EC2ECRProfile"
  role = aws_iam_role.ec2_ecr_role.name
}

resource "aws_security_group" "allow_ssh_http" {
  name        = "allow_ssh_http"
  description = "Allows SSH and HTTP traffic"

  ingress {
    description = "SSH desde cualquier lugar"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP desde cualquier lugar"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    description = "Puerto 5000 para el microservicio"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_http"
  }
}

# Obtener la VPC default
data "aws_vpc" "default" {
  default = true
}

# Obtener todas las subnets de la VPC default
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Actualizar la instancia EC2 para usar la primera subnet disponible
resource "aws_instance" "ec2_instance" {
  ami                    = "ami-0a897ba00eaed7398"
  instance_type          = "t2.micro"
  subnet_id              = tolist(data.aws_subnets.default.ids)[0]  # Usa la primera subnet
  iam_instance_profile   = aws_iam_instance_profile.ec2_ecr_profile.name
  vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              service docker start
              usermod -a -G docker ec2-user

              # Instalar el agente de SSM
              yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent

              # Configurar Docker para usar ECR
              aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${var.aws_account_id}.dkr.ecr.us-west-2.amazonaws.com
              EOF

  tags = {
    Name = "SimpleDockerServiceInstance"
  }
}
output "ec2_public_ip" {
  value = aws_instance.ec2_instance.public_ip
}

resource "aws_s3_bucket" "artifact_store" {
  bucket        = "codepipeline-artifacts-${var.aws_account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "artifact_store_versioning" {
  bucket = aws_s3_bucket.artifact_store.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket para el datalake (actualizado para usar el nombre existente)
resource "aws_s3_bucket" "datalake_raw_s3" {
  bucket        = "datalake-raw-s3-${var.aws_account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "datalake_raw_s3_versioning" {
  bucket = aws_s3_bucket.datalake_raw_s3.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Crear una aplicación de CodeDeploy
resource "aws_codedeploy_app" "simple_docker_service" {
  compute_platform = "Server"
  name             = "SimpleDockerService"
}

# Crear un grupo de despliegue de CodeDeploy
resource "aws_codedeploy_deployment_group" "simple_docker_service" {
  app_name              = aws_codedeploy_app.simple_docker_service.name
  deployment_group_name = "SimpleDockerServiceDeploymentGroup"
  service_role_arn      = aws_iam_role.codedeploy_role.arn

  # Configurar el grupo de despliegue para usar una instancia EC2 específica
  ec2_tag_filter {
    key   = "Name"
    type  = "KEY_AND_VALUE"
    value = "SimpleDockerServiceInstance"
  }

  # Configurar el tipo de despliegue (Blue/Green o In-Place)
  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  # Configurar el comportamiento de despliegue
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

# Rol de IAM para CodeDeploy
resource "aws_iam_role" "codedeploy_role" {
  name = "CodeDeployRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })
}

# Política adicional para CodeDeploy
resource "aws_iam_policy" "codedeploy_additional_permissions" {
  name        = "CodeDeployAdditionalPermissions"
  description = "Additional permissions for CodeDeploy to interact with S3 and EC2"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*",
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.artifact_store.arn}",
          "${aws_s3_bucket.artifact_store.arn}/*"
        ]
      },
      {
        Action = [
          "ec2:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_additional_policy" {
  policy_arn = aws_iam_policy.codedeploy_additional_permissions.arn
  role       = aws_iam_role.codedeploy_role.name
}

# Adjuntar la política AWSSystemsManagerManagedInstanceCore al rol de EC2
resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ec2_ecr_role.name
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Grupo de seguridad para RDS Aurora"

  ingress {
    description     = "PostgreSQL desde EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.allow_ssh_http.id]
  }

  ingress {
    description     = "PostgreSQL desde DMS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.dms.dms_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-aurora-sg"
  }
}

# Actualizar el cluster de Aurora
resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier     = "aurora-cluster-demo"
  engine                = "aurora-postgresql"
  engine_version        = "15.3"
  database_name         = "demodb"
  master_username       = "demouser"
  master_password       = "Demo1234!"
  skip_final_snapshot   = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name = aws_db_subnet_group.aurora.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.demo_params.name

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 1.0
  }

  enable_http_endpoint = true
  iam_database_authentication_enabled = true
}

resource "aws_rds_cluster_instance" "aurora_instance" {
  cluster_identifier = aws_rds_cluster.aurora_cluster.id
  instance_class    = "db.serverless"
  engine            = aws_rds_cluster.aurora_cluster.engine
  engine_version    = aws_rds_cluster.aurora_cluster.engine_version
}

# Actualizar el subnet group de Aurora para usar todas las subnets disponibles
resource "aws_db_subnet_group" "aurora" {
  name       = "aurora-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "Aurora DB subnet group"
  }
}

module "dms" {
  source = "../../modules/dms"
  
  region                    = "us-west-2"
  region_alias              = "usw2"
  environment               = "prod"
  business_unit             = "microservice"
  account_id                = var.aws_account_id
  
}

/* resource "aws_secretsmanager_secret" "rds_credentials_db" {
  name = "rds-credentials-db-1"
  description = "Credenciales para la base de datos Aurora PostgreSQL"
  force_overwrite_replica_secret = true
}

resource "aws_secretsmanager_secret_version" "rds_credentials_db" {
  secret_id = aws_secretsmanager_secret.rds_credentials_db.id
  secret_string = jsonencode({
    username = aws_rds_cluster.aurora_cluster.master_username
    password = aws_rds_cluster.aurora_cluster.master_password
    engine   = "postgres"
    host     = aws_rds_cluster.aurora_cluster.endpoint
    port     = 5432
    dbname   = aws_rds_cluster.aurora_cluster.database_name
  })
} */

module "rds_to_datalake" {
  source = "../../modules/rds_to_datalake"
  
  region                    = "us-west-2"
  region_alias              = "usw2"
  environment               = "prod"
  service                   = "microservice"
  business_unit             = "microservice"
  account_id                = var.aws_account_id
  
  # RDS Configuration
  cluster                   = aws_rds_cluster.aurora_cluster.cluster_identifier
  cluster_endpoint          = aws_rds_cluster.aurora_cluster.endpoint
  database_name             = aws_rds_cluster.aurora_cluster.database_name
  
  # Secrets Manager ARN para las credenciales de RDS
  secrets_manager_arn       ="arn-temp" #aws_secretsmanager_secret.rds_credentials_db.arn
  
  # DMS Instance ARN
  replication_instance_arn  = module.dms.replication_instance_arn
  
  # Tags y compliance
  compliance               = "none"
}

# Rol DMS para infraestructura (actualizado para coincidir con el nombre esperado)
resource "aws_iam_role" "dms_infrastructure_role" {
  name = "usw2-prod-infrastructure-dms-role"  # Nombre exacto que espera el endpoint

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "dms.amazonaws.com",
            "dms.us-west-2.amazonaws.com",  # Servicio regional para us-west-2
            "dms.us-east-1.amazonaws.com"   # Servicio regional para us-east-1
          ]
        }
      }
    ]
  })
}

# Política para el rol DMS
resource "aws_iam_role_policy" "dms_infrastructure_policy" {
  name = "dms-infrastructure-policy"
  role = aws_iam_role.dms_infrastructure_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:*",
          "s3:*",
          "secretsmanager:*",
          "kinesis:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards",
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ],
        Resource = module.rds_to_datalake.kinesis-stream-arn  # Referencia específica al ARN del stream
      }
    ]
  })
}

resource "aws_rds_cluster_parameter_group" "demo_params" {
  family      = "aurora-postgresql15"
  name        = "demo-params"
  description = "Parameter group for Aurora PostgreSQL cluster with logical replication enabled"

  parameter {
    name  = "rds.logical_replication"
    value = "1"
    apply_method = "pending-reboot"
  }

  tags = {
    Name = "demo-params"
  }
}

