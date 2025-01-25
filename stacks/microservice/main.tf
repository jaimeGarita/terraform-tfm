resource "aws_iam_role" "new_codepipeline_role" {
  name = "GabiotaRM"  # Nombre más corto
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "codepipeline.amazonaws.com"  # Solo CodePipeline, no codestar-connections
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
          "codepipeline:PutJobSuccessResult"
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
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::codepipelinestartertempla-codepipelineartifactsbuc-ceeedyolaysk/*"
      },
      {
        Action   = [
          "codestar-connections:UseConnection",
          "codestar-connections:ListConnections",
          "codestar-connections:GetConnection"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:codestar-connections:us-west-2:195275638124:connection/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_codepipeline_permissions" {
  policy_arn = aws_iam_policy.codepipeline_permissions.arn
  role       = aws_iam_role.new_codepipeline_role.name
}

resource "aws_codepipeline" "my_pipeline" {
  name           = "SimpleDockerService"
  execution_mode = "QUEUED"
  pipeline_type  = "V2"
  role_arn       = aws_iam_role.new_codepipeline_role.arn
  tags           = {}
  tags_all       = {}

  artifact_store {
    location = "codepipelinestartertempla-codepipelineartifactsbuc-ceeedyolaysk"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      category           = "Source"
      configuration      = {
        "BranchName"       = "main"
        "ConnectionArn"    = aws_codestarconnections_connection.github_connection.arn
        "FullRepositoryId" = "jaimeGarita/api-tfm"
      }
      input_artifacts    = []
      name               = "CodeConnections"
      output_artifacts   = ["SourceOutput"]
      owner              = "AWS"
      provider           = "CodeStarSourceConnection"
      role_arn           = aws_iam_role.new_codepipeline_role.arn
      run_order          = 1
      version            = "1"
    }
  }

  stage {
    name = "Build_and_Deploy"

    action {
      category           = "Build"
      configuration      = {
        "ProjectName" = "SimpleDockerService"
      }
      input_artifacts    = ["SourceOutput"]
      name               = "Docker_Build_Tag_and_Push"
      output_artifacts   = []
      owner              = "AWS"
      provider           = "CodeBuild"
      role_arn           = aws_iam_role.new_codepipeline_role.arn
      run_order          = 1
      version            = "1"
    }
  }

  trigger {
    provider_type = "CodeStarSourceConnection"

    git_configuration {
      source_action_name = "CodeConnections"

      push {
        branches {
          includes = [
            "main",
          ]
        }
      }
    }
  }
}

resource "aws_codestarconnections_connection" "github_connection" {
  name         = "api-tfm-connection"
  provider_type = "GitHub"
}
