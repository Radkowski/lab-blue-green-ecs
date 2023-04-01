locals {
  user_data        = fileexists("./config.yaml") ? yamldecode(file("./config.yaml")) : jsondecode(file("./config.json"))
  REGION           = local.user_data.Parameters.Region
  DEPLOYMENTPREFIX = local.user_data.Parameters.DeploymentPrefix
  VPCCIDR          = local.user_data.Parameters.VPCCIDR
  AUTHTAGS         = local.user_data.Parameters.AuthTags
  IMAGE            = local.user_data.Parameters.Image
  CODEPIPELINE     = local.user_data.Parameters.CodePipeline
  CODECOMMIT       = local.user_data.Parameters.CodeCommit
}
