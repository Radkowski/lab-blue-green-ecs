data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

variable "DeploymentName" {}
variable "AUTHTAGS" {}
variable "IMAGE" {}
variable "REGION" {}



resource "aws_iam_role" "lambda-role" {
  name = join("", [var.DeploymentName, "-lambda-role"])
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = join("", [var.DeploymentName, "-lambda-policy"])

    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "logs:CreateLogGroup",
          "Resource" : join("", ["arn:aws:logs:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":*"])
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "ecs:RegisterTaskDefinition",
            "ecs:DeleteTaskDefinitions",
            "ecs:DescribeTaskDefinition",
            "ecs:DeregisterTaskDefinition"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : "iam:PassRole",
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : ["ssm:PutParameter", "ssm:GetParameter", "ssm:DeleteParameter"],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : [
            join("", ["arn:aws:logs:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":", "log-group:/aws/lambda/", var.DeploymentName, "-lambda:*"])
          ]
        }
      ]
    })
  }
}


resource "aws_iam_role" "radkowski-task-role" {
  name = join("", [var.DeploymentName, "-ecs-role"])
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
  inline_policy {
    name = join("", [var.DeploymentName, "-instance-profile-role"])
    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : ["logs:CreateLogGroup"],
          "Resource" : [
            join("", ["arn:aws:logs:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":log-group:/ecs/radkowskilab:*"])
          ]
        }
      ]
    })
  }
}


data "archive_file" "lambda-code" {
  type        = "zip"
  output_path = "lambda-code.zip"
  source {
    content  = <<EOF
import boto3


def create_ssm_param (name,value):
    ssm_client = boto3.client('ssm')
    response = ssm_client.put_parameter(
    Name=name,
    Description='some_desc',
    Value=value,
    Type='String',
    Overwrite=True,
    Tier='Standard',
    DataType='text'
    )
    return 0
    
    
def delete_ssm_param (name):
    ssm_client = boto3.client('ssm')
    response = ssm_client.delete_parameter(Name=name)
    return 0

def create_task(params):
    
    ecs_client = boto3.client('ecs')

    response = ecs_client.register_task_definition(
        family=params['family'],
        taskRoleArn=params['role_arn'],
        executionRoleArn=params['role_arn'],
        networkMode='awsvpc',
        containerDefinitions=[
            {
                'name': params['name'],
                'image': params['image'],
                'cpu': 0,
                'portMappings': [
                    {
                        'containerPort': int(params['container_port']),
                        'hostPort': int(params['container_port']),
                        'protocol': 'tcp'
                    },
                ],
                'essential': True,        
                'logConfiguration': {
                    'logDriver': 'awslogs',
                    'options': {
                        "awslogs-create-group" : "true",
                        "awslogs-group" : "/ecs/radkowskilab",
                        "awslogs-region" : params['region'],
                        "awslogs-stream-prefix" : "ecs"
                    },
                }
            }
        ],
        requiresCompatibilities=[
            'FARGATE',
        ],
        cpu='256',
        memory='512',
        tags=[
            {
                'key': 'string',
                'value': 'string'
            },
        ],
        runtimePlatform={
            'cpuArchitecture': 'ARM64',
            'operatingSystemFamily': 'LINUX'
        }
    )
    # print (response['taskDefinition']['taskDefinitionArn'])
    create_ssm_param (params['parameter_name'],response['taskDefinition']['taskDefinitionArn'])
    return 0
    
def destroy_task(task_arn,parameter_name):
        ecs_client = boto3.client('ecs')
        in_the_loop = True
        while in_the_loop:
            try:
                detect_task = ecs_client.describe_task_definition(taskDefinition=task_arn)
                print(' Deregistering: ',detect_task['taskDefinition']['taskDefinitionArn'])
                delete_task = ecs_client.deregister_task_definition(taskDefinition=(detect_task['taskDefinition']['taskDefinitionArn']))
            except:
                 in_the_loop = False

        while True:
            try:
                delete_ssm_param (parameter_name)
            except:
                return 0
                
                

def lambda_handler(event, context):
  if event['param']['create']:
        create_task(event['param']) 
  else:
        destroy_task(event['param']['task_arn'],event['param']['parameter_name'])
     

  return 0

EOF
    filename = "lambda_function.py"
  }
}


resource "aws_lambda_function" "lambda" {
  description      = "Changeme"
  architectures    = ["arm64"]
  filename         = data.archive_file.lambda-code.output_path
  source_code_hash = data.archive_file.lambda-code.output_base64sha256
  role             = aws_iam_role.lambda-role.arn
  function_name    = join("", [var.DeploymentName, "-lambda"])
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  timeout          = 15
  memory_size      = 128
  tags             = merge(var.AUTHTAGS, { Name = join("", [var.DeploymentName, "-lambda"]) })
}


resource "lambdabased_resource" "lambda_task" {
  function_name = aws_lambda_function.lambda.function_name
  triggers = {
    trigger_a = "start_me"
  }
  input = jsonencode({
    param = {
      create         = true
      parameter_name = join("", ["/custom/RadkowskiLab/", var.DeploymentName, "/task_def"])
      family         = join("", [var.DeploymentName, "-task-def"]),
      role_arn       = aws_iam_role.radkowski-task-role.arn,
      name           = var.IMAGE.Name,
      image          = var.IMAGE.URL,
      container_port = var.IMAGE.Port,
      region         = var.REGION
    }
  })
  conceal_input  = true
  conceal_result = true
  finalizer {
    function_name = aws_lambda_function.lambda.function_name
    input = jsonencode({
      param = {
        create         = false,
        parameter_name = join("", ["/custom/RadkowskiLab/", var.DeploymentName, "/task_def"]),
        task_arn       = join("", ["arn:aws:ecs:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":task-definition/", var.DeploymentName, "-task-def"])
      }
    })
  }
}


output "ECS_ROLE" {
  value = aws_iam_role.radkowski-task-role
}
