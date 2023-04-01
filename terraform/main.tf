module "LAMBDA-ECS-TASK" {
  source         = "./lambda-ecs-task"
  DeploymentName = local.DEPLOYMENTPREFIX
  REGION         = local.REGION
  AUTHTAGS       = local.AUTHTAGS
  IMAGE          = local.IMAGE
}


module "NETWORK" {
  source         = "./network"
  depends_on     = [module.LAMBDA-ECS-TASK]
  DeploymentName = local.DEPLOYMENTPREFIX
  VPC_CIDR       = local.VPCCIDR
  AUTHTAGS       = local.AUTHTAGS
}


module "ALB" {
  depends_on     = [module.NETWORK]
  source         = "./alb"
  DeploymentName = local.DEPLOYMENTPREFIX
  VPCID          = module.NETWORK.VPCID
  PUBSUBNETSID   = module.NETWORK.PUBSUBNETSID[*].id
}



module "ECS" {
  depends_on     = [module.ALB]
  source         = "./ecs"
  DeploymentName = local.DEPLOYMENTPREFIX
  REGION         = local.REGION
  IMAGE          = local.IMAGE
  PRIVSUBNETSID  = module.NETWORK.PRIVSUBNETSID[*].id
  ALB            = module.ALB.ALB
  TG             = module.ALB.TG
  SG             = module.ALB.SG
}

module "CICD" {
  depends_on     = [module.ECS]
  source         = "./cicd"
  DeploymentName = local.DEPLOYMENTPREFIX
  REGION         = local.REGION
  ECS_CLUSTER    = module.ECS.ECS_CLUSTER
  ECS_SERVICE    = module.ECS.ECS_SERVICE
  TG             = module.ALB.TG
  LISTENERS      = module.ALB.LISTENERS
  CODEPIPELINE   = local.CODEPIPELINE
  CODECOMMIT     = local.CODECOMMIT
  IMAGE          = local.IMAGE
}



