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
          "codepipeline:PollForJobs",
          "codepipeline:PutJobFailureResult",
          "codepipeline:PutJobSuccessResult",
          "ecr:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:ListBuildsForProject"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketVersioning",
          "s3:ListBucket",
          "s3:ListBucketVersions"
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
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/jaimeGarita/api-tfm.git"
    git_clone_depth = 1

    git_submodules_config {
      fetch_submodules = true
    }
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
        "Owner"      = "jaimeGarita"           # Propietario del repositorio
        "Repo"       = "api-tfm"               # Nombre del repositorio
        "Branch"     = "main"                  # Rama a monitorear
        "OAuthToken" = "SECRET_GITHUB_TOKEN"    # Reemplaza con tu PAT de GitHub
      }
      input_artifacts  = []
      name             = "GitHub_Source"
      output_artifacts = ["SourceOutput"]
      owner            = "ThirdParty"          # Cambia de "AWS" a "ThirdParty"
      provider         = "GitHub"              # Cambia de "CodeStarSourceConnection" a "GitHub"
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
      name             = "Docker_Build_Tag_and_Push"
      output_artifacts = []
      owner            = "AWS"
      provider         = "CodeBuild"
      role_arn         = aws_iam_role.new_codepipeline_role.arn
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
  description = "Policy to allow EC2 to pull images from ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:*"
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

resource "aws_instance" "ec2_instance" {
  ami                    = "ami-0a897ba00eaed7398"
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_instance_profile.ec2_ecr_profile.name
  vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              service docker start
              usermod -a -G docker ec2-user

              aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${var.aws_account_id}.dkr.ecr.us-west-2.amazonaws.com

              docker pull ${var.aws_account_id}.dkr.ecr.us-west-2.amazonaws.com/simple-docker-service:latest
              docker run -d -p 80:5000 ${var.aws_account_id}.dkr.ecr.us-west-2.amazonaws.com/simple-docker-service:latest
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

