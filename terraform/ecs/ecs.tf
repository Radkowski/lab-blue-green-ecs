variable "REGION" {}
variable "DeploymentName" {}
variable "IMAGE" {}
variable "PRIVSUBNETSID" {}
variable "ALB" {}
variable "TG" {}
variable "SG" {}
# variable ECS_ROLE {}


data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_ssm_parameter" "task_info" {
  name = join("", ["/custom/RadkowskiLab/", var.DeploymentName, "/task_def"])
}


resource "aws_ecs_cluster" "ecs" {
  name = join("", [var.DeploymentName, "-ECS"])
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}


resource "aws_cloudwatch_log_group" "taskloggroup" {
  name              = "/ecs/radkowskilab"
  retention_in_days = 14
}


resource "aws_ecs_service" "servicedef" {
  name            = join("", [var.DeploymentName, "-service"])
  cluster         = aws_ecs_cluster.ecs.id
  task_definition = data.aws_ssm_parameter.task_info.value
  desired_count   = 2
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = var.PRIVSUBNETSID
    security_groups  = [var.SG.id]
    assign_public_ip = false
  }
  deployment_controller {
    type = "CODE_DEPLOY"
  }
  load_balancer {
    target_group_arn = var.TG[0].arn
    container_name   = var.IMAGE.Name
    container_port   = var.IMAGE.Port
  }
}



output "ECS_CLUSTER" {
  value = aws_ecs_cluster.ecs
}

output "ECS_SERVICE" {
  value = aws_ecs_service.servicedef
}

