variable "DeploymentName" {}
variable "VPCID" {}
variable "PUBSUBNETSID" {}


locals {
  alb_ports = [80, 8080]
}


resource "aws_security_group" "alb-sg" {
  name        = "http-and-https-only-sg"
  description = "Allow http(s)"
  vpc_id      = var.VPCID
  ingress = [
    {
      description      = "https traffic"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
    {
      description      = "http traffic"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
    {
      description      = "http traffic"
      from_port        = 8080
      to_port          = 8080
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
  egress = [
    {
      description      = "Default rule"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
}


resource "aws_lb" "alb" {
  name                       = join("", [var.DeploymentName, "-ALB"])
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb-sg.id]
  subnets                    = var.PUBSUBNETSID
  enable_deletion_protection = false
  ip_address_type            = "dualstack"
}


resource "aws_lb_target_group" "alb-tg" {
  count       = 2
  name        = join("", [var.DeploymentName, "-ALB-TG-", count.index])
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.VPCID
}


resource "aws_lb_listener" "front_end" {
  count             = 2
  load_balancer_arn = aws_lb.alb.arn
  port              = local.alb_ports[count.index]
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-tg[0].arn
  }
}



output "ALB" {
  value = aws_lb.alb
}

output "TG" {
  value = aws_lb_target_group.alb-tg
}

output "SG" {
  value = aws_security_group.alb-sg
}

output "LISTENERS" {
  value = aws_lb_listener.front_end
}
