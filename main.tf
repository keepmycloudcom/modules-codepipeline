### Variables
variable "name" { type = string }
variable "tags" { type = map(string) }
variable "aws_region" { type = string }
variable "aws_account" { type = string }
variable "project_env" { type = string }
variable "project_name" { type = string }
variable "repo_name" { type = string }
variable "ecs_cluster" { type = string }
variable "codestar_conector" { type = string }
variable "service_name" { type = string }

variable "compute_type" {
  type    = string
  default = "BUILD_GENERAL1_SMALL"
}
variable "secret_environment" {
  type    = list(object({ name = string, value = string }))
  default = [{ name = "test", value = "test" }]
}
variable "detect_changes" {
  type    = bool
  default = true
}
# code pipeline


resource "aws_codepipeline" "container_pipeline" {
  name     = var.name
  role_arn = aws_iam_role.code_pipeline.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.id
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name     = "Source"
      category = "Source"
      owner    = "AWS"
      configuration = {
        BranchName           = "${var.project_env}"
        ConnectionArn        = data.aws_codestarconnections_connection.git.arn
        FullRepositoryId     = "${var.repo_name}"
        OutputArtifactFormat = "CODE_ZIP"
        DetectChanges        = "${var.detect_changes}"
      }
      provider = "CodeStarSourceConnection"
      version  = "1"
      output_artifacts = [
        "SourceArtifact"
      ]
      run_order = 1
    }
  }

  stage {
    name = "Build"
    action {
      name     = "Build"
      category = "Build"
      owner    = "AWS"
      configuration = {
        EnvironmentVariables = jsonencode(var.secret_environment)
        ProjectName          = "${var.name}-container-build"
      }
      input_artifacts = [
        "SourceArtifact"
      ]
      provider = "CodeBuild"
      version  = "1"
      output_artifacts = [
        "BuildArtifact"
      ]
      run_order = 1
    }
  }
  stage {
    name = "Deploy"
    action {
      name     = "Deploy"
      category = "Deploy"
      owner    = "AWS"
      configuration = {
        ClusterName       = "${var.ecs_cluster}"
        ServiceName       = "${var.service_name}"
        DeploymentTimeout = 15
      }
      input_artifacts = [
        "BuildArtifact"
      ]
      provider  = "ECS"
      version   = "1"
      run_order = 1
    }
  }
}
#s3 bucket for codepipeline artifacts
resource "aws_s3_bucket" "codepipeline_artifacts" {
<<<<<<< HEAD
  bucket        = "${var.name}-build-artifacts"
  force_destroy = true
  acl           = "private"
=======
  bucket = "${var.name}-build-artifacts"
  force_destroy = true
  acl = "private"
>>>>>>> e40fcb2f230be95aa3cd1d2c44c329d4b29e5a40
  versioning {
    enabled = false
  }

  lifecycle_rule {
    enabled = true
    id      = "codepipeline-artifacts"
    prefix  = ""
    tags = {
      Name = "codepipeline-artifacts"
    }
    expiration {
      days = 30
    }
  }
}

# get codestar connection arn
data "aws_codestarconnections_connection" "git" {
  name = var.codestar_conector
}

data "aws_iam_policy_document" "code_build_assume" {
  statement {
    sid     = "TrustRelationships"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "code_build_s3" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation"
    ]
    resources = [
      aws_s3_bucket.codepipeline_artifacts.arn,
      "${aws_s3_bucket.codepipeline_artifacts.arn}/*",
    ]
  }
}

data "aws_iam_policy_document" "code_build_vpc" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:*"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
    "ec2:CreateNetworkInterfacePermission", ]
    resources = [
      "arn:aws:ec2:${var.aws_region}:${var.aws_account}:network-interface/*"
    ]
  }
}

resource "aws_iam_role_policy_attachment" "code_build_ecr_power_user" {
  role       = aws_iam_role.code_build.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy_attachment" "code_build_vpc_read_only" {
  role       = aws_iam_role.code_build.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "code_secret_manager" {
  role       = aws_iam_role.code_build.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_role" "code_build" {
  path = "/service-role/"
  name = "${var.name}-container-build"

  assume_role_policy   = data.aws_iam_policy_document.code_build_assume.json
  max_session_duration = 3600

  inline_policy {
    name   = "CodeBuildS3Policy"
    policy = data.aws_iam_policy_document.code_build_s3.json
  }
}

resource "aws_iam_role" "code_pipeline" {
  path                 = "/service-role/"
  name                 = "${var.name}-code-pipeline"
  assume_role_policy   = data.aws_iam_policy_document.code_pipeline_assume.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "code_pipeline" {
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["*"]
    condition {
      test     = "StringEqualsIfExists"
      variable = "iam:PassedToService"
      values = [
        "cloudformation.amazonaws.com",
        "elasticbeanstalk.amazonaws.com",
        "ec2.amazonaws.com",
        "ecs-tasks.amazonaws.com",
      ]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "codecommit:CancelUploadArchive",
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:GetRepository",
      "codecommit:GetUploadArchiveStatus",
      "codecommit:UploadArchive",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:RegisterApplicationRevision",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "codestar-connections:UseConnection",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticbeanstalk:*",
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "cloudwatch:*",
      "s3:*",
      "sns:*",
      "cloudformation:*",
      "rds:*",
      "sqs:*",
      "ecs:*",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
      "lambda:ListFunctions",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "opsworks:CreateDeployment",
      "opsworks:DescribeApps",
      "opsworks:DescribeCommands",
      "opsworks:DescribeDeployments",
      "opsworks:DescribeInstances",
      "opsworks:DescribeStacks",
      "opsworks:UpdateApp",
      "opsworks:UpdateStack",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "cloudformation:CreateStack",
      "cloudformation:DeleteStack",
      "cloudformation:DescribeStacks",
      "cloudformation:UpdateStack",
      "cloudformation:CreateChangeSet",
      "cloudformation:DeleteChangeSet",
      "cloudformation:DescribeChangeSet",
      "cloudformation:ExecuteChangeSet",
      "cloudformation:SetStackPolicy",
      "cloudformation:ValidateTemplate",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "codebuild:BatchGetBuildBatches",
      "codebuild:StartBuildBatch",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "devicefarm:ListProjects",
      "devicefarm:ListDevicePools",
      "devicefarm:GetRun",
      "devicefarm:GetUpload",
      "devicefarm:CreateUpload",
      "devicefarm:ScheduleRun",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "servicecatalog:ListProvisioningArtifacts",
      "servicecatalog:CreateProvisioningArtifact",
      "servicecatalog:DescribeProvisioningArtifact",
      "servicecatalog:DeleteProvisioningArtifact",
      "servicecatalog:UpdateProduct",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "cloudformation:ValidateTemplate",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:DescribeImages",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "states:DescribeExecution",
      "states:DescribeStateMachine",
      "states:StartExecution",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "appconfig:StartDeployment",
      "appconfig:StopDeployment",
      "appconfig:GetDeployment",
    ]
    resources = ["*"]
  }
}

# policy
resource "aws_iam_policy" "code_pipeline" {
  name        = "${var.name}-code-pipeline"
  description = "Policy for the ${var.name} environment"
  policy      = data.aws_iam_policy_document.code_pipeline.json
}

resource "aws_iam_policy" "codebuild_vpc" {
  name        = "${var.name}-codebuild-vpc"
  description = "Policy for the ${var.name} environment"
  policy      = data.aws_iam_policy_document.code_build_vpc.json
}

resource "aws_iam_role_policy_attachment" "code_build_vpc" {
  role       = aws_iam_role.code_build.name
  policy_arn = aws_iam_policy.codebuild_vpc.arn
}

# assign policy to role
resource "aws_iam_role_policy_attachment" "code_pipeline" {
  role       = aws_iam_role.code_pipeline.name
  policy_arn = aws_iam_policy.code_pipeline.arn
}

data "aws_iam_policy_document" "code_pipeline_assume" {
  statement {
    sid     = "TrustRelationships"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

# code build project
resource "aws_codebuild_project" "container_build" {
  name         = "${var.name}-container-build"
  description  = "Builds the container for the ${var.name} environment"
  service_role = aws_iam_role.code_build.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type                = var.compute_type
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "CODEBUILD_CONFIG_AUTO_DISCOVER"
      value = "true"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml" #file("${path.module}/tpl/codebuild/core.yaml.tpl")
  }

  build_timeout = 20
  tags = {
    "Name" = "${var.name}-container-build"
  }

  #  vpc_config {
  #    vpc_id = module.vpc.id
  #    security_group_ids = [
  #      module.vpc.default_security_group_id,
  #    ]
  #    subnets = module.vpc.private_subnets
  #  }
}

# create security group rule
#resource "aws_security_group_rule" "code_build" {
#  type              = "egress"
#  from_port         = 0
#  to_port           = 65535
#  protocol          = "tcp"
#  security_group_id = module.vpc.default_security_group_id
#  cidr_blocks       = ["0.0.0.0/0"]
#}

### Outputs
#output "bucket" {
#  value = {
#    id  = aws_s3_bucket.bucket.id
#    arn = aws_s3_bucket.bucket.arn
#  }
#}

#output "rw_policy_arn" { value = aws_iam_policy.s3-rw.arn }
#output "ro_policy_arn" { value = aws_iam_policy.s3-ro.arn }
