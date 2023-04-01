variable "DeploymentName" {}
variable "REGION" {}
variable "ECS_CLUSTER" {}
variable "TG" {}
variable "LISTENERS" {}
variable "ECS_SERVICE" {}
variable "CODEPIPELINE" {}
variable "CODECOMMIT" {}
variable "IMAGE" {}



data "aws_caller_identity" "current" {}
data "aws_region" "current" {}



resource "aws_iam_role" "codedeploy-role" {
  name = join("", [var.DeploymentName, "-codedeploy-role"])
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"]
}


resource "aws_iam_role" "codepipeline-role" {
  name = join("", [var.DeploymentName, "-codepipeline-role"])
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = join("", [var.DeploymentName, "-instance-profile-role"])
    policy = jsonencode({
      "Statement" : [
        {
          "Action" : [
            "iam:PassRole"
          ],
          "Resource" : "*",
          "Effect" : "Allow",
          "Condition" : {
            "StringEqualsIfExists" : {
              "iam:PassedToService" : [
                "cloudformation.amazonaws.com",
                "elasticbeanstalk.amazonaws.com",
                "ec2.amazonaws.com",
                "ecs-tasks.amazonaws.com"
              ]
            }
          }
        },
        {
          "Action" : [
            "codecommit:CancelUploadArchive",
            "codecommit:GetBranch",
            "codecommit:GetCommit",
            "codecommit:GetRepository",
            "codecommit:GetUploadArchiveStatus",
            "codecommit:UploadArchive"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "codedeploy:CreateDeployment",
            "codedeploy:GetApplication",
            "codedeploy:GetApplicationRevision",
            "codedeploy:GetDeployment",
            "codedeploy:GetDeploymentConfig",
            "codedeploy:RegisterApplicationRevision"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "codestar-connections:UseConnection"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
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
            "ecr:*"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "lambda:InvokeFunction",
            "lambda:ListFunctions"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "opsworks:CreateDeployment",
            "opsworks:DescribeApps",
            "opsworks:DescribeCommands",
            "opsworks:DescribeDeployments",
            "opsworks:DescribeInstances",
            "opsworks:DescribeStacks",
            "opsworks:UpdateApp",
            "opsworks:UpdateStack"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "cloudformation:CreateStack",
            "cloudformation:DeleteStack",
            "cloudformation:DescribeStacks",
            "cloudformation:UpdateStack",
            "cloudformation:CreateChangeSet",
            "cloudformation:DeleteChangeSet",
            "cloudformation:DescribeChangeSet",
            "cloudformation:ExecuteChangeSet",
            "cloudformation:SetStackPolicy",
            "cloudformation:ValidateTemplate"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "codebuild:BatchGetBuilds",
            "codebuild:StartBuild",
            "codebuild:BatchGetBuildBatches",
            "codebuild:StartBuildBatch"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "devicefarm:ListProjects",
            "devicefarm:ListDevicePools",
            "devicefarm:GetRun",
            "devicefarm:GetUpload",
            "devicefarm:CreateUpload",
            "devicefarm:ScheduleRun"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "servicecatalog:ListProvisioningArtifacts",
            "servicecatalog:CreateProvisioningArtifact",
            "servicecatalog:DescribeProvisioningArtifact",
            "servicecatalog:DeleteProvisioningArtifact",
            "servicecatalog:UpdateProduct"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "cloudformation:ValidateTemplate"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "ecr:DescribeImages"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "states:DescribeExecution",
            "states:DescribeStateMachine",
            "states:StartExecution"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "appconfig:StartDeployment",
            "appconfig:StopDeployment",
            "appconfig:GetDeployment"
          ],
          "Resource" : "*"
        }
      ],
      "Version" : "2012-10-17"
      }
    )
  }
}


resource "aws_iam_role" "event-role" {
  name = join("", [var.DeploymentName, "-eventbridge-role"])
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "events.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = join("", [var.DeploymentName, "-instance-profile-role"])
    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "codepipeline:StartPipelineExecution"
          ],
          "Resource" : [aws_codepipeline.image-pipeline.arn]
        }
      ]
    })
  }
}


resource "aws_codedeploy_app" "cdp-app" {
  compute_platform = "ECS"
  name             = join("", [var.DeploymentName, "-codedeploy-app"])
}


resource "aws_codedeploy_deployment_group" "cd_deployment_group" {
  app_name               = aws_codedeploy_app.cdp-app.name
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = join("", [var.DeploymentName, "-deployment-grp"])
  service_role_arn       = aws_iam_role.codedeploy-role.arn
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
  blue_green_deployment_config {
    deployment_ready_option {
      # action_on_timeout = "CONTINUE_DEPLOYMENT"
      action_on_timeout    = "STOP_DEPLOYMENT"
      wait_time_in_minutes = 60
    }
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }
  ecs_service {
    cluster_name = var.ECS_CLUSTER.name
    service_name = var.ECS_SERVICE.name
  }
  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [var.LISTENERS[0].arn]
      }
      test_traffic_route {
        listener_arns = [var.LISTENERS[1].arn]
      }
      target_group {
        name = var.TG[0].name
      }
      target_group {
        name = var.TG[1].name
      }
    }
  }
}


resource "aws_codepipeline" "image-pipeline" {
  name     = join("", [var.DeploymentName, "-pipeline"])
  role_arn = aws_iam_role.codepipeline-role.arn
  artifact_store {
    location = var.CODEPIPELINE.Bucket
    type     = "S3"
  }
  stage {
    name = "Source"
    action {
      name             = "Git_Repository"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["SourceArtifact"]
      configuration = {
        RepositoryName = var.CODECOMMIT.Name
        BranchName     = var.CODECOMMIT.Branch
      }
    }
    action {
      name             = "ECR_Repository"
      category         = "Source"
      owner            = "AWS"
      provider         = "ECR"
      version          = "1"
      output_artifacts = ["MyImage"]
      configuration = {
        RepositoryName = "radkowski"
        ImageTag       = "nginx"
      }
    }
  }
  stage {
    name = "Deploy"
    action {
      name            = "Container_Deployment"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = ["SourceArtifact", "MyImage"]
      version         = "1"
      configuration = {
        AppSpecTemplateArtifact : "SourceArtifact"
        AppSpecTemplatePath : "appspec.yaml"
        ApplicationName : "RadLab-codedeploy-app"
        DeploymentGroupName : "RadLab-deployment-grp"
        Image1ArtifactName : "MyImage"
        Image1ContainerName : "IMAGE1_NAME"
        TaskDefinitionTemplateArtifact : "SourceArtifact"
        TaskDefinitionTemplatePath : "taskdef.json"
      }
    }
  }
}


resource "aws_cloudwatch_event_rule" "start-pipeline-after-ecr-push" {
  name        = join("", [var.DeploymentName, "-rule"])
  description = "Starts pipeline once image is pushed into ECR"
  event_pattern = jsonencode({
    "source" : ["aws.ecr"],
    "detail-type" : ["ECR Image Action"],
    "detail" : {
      "action-type" : ["PUSH"],
      "result" : ["SUCCESS", "FAILURE"],
      "repository-name" : ["radkowski"],
      "image-tag" : ["nginx"]
    }
  })
}


resource "aws_cloudwatch_event_target" "codepipeline" {
  rule      = aws_cloudwatch_event_rule.start-pipeline-after-ecr-push.name
  target_id = "TriggerCP"
  arn       = aws_codepipeline.image-pipeline.arn
  role_arn  = aws_iam_role.event-role.arn
}
