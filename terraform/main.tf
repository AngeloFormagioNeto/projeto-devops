provider "aws" {
  region = var.region
}

provider "random" {}

locals {
  common_tags = {
    Project     = var.app_name
    Environment = var.environment
    Temporary   = var.is_temporary ? "true" : "false"
    Terraform   = "true"
  }
}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

# VPC Configuration
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

# Security Groups
resource "aws_security_group" "lb" {
  name        = "lb-sg-${random_string.suffix.result}"
  description = "ALB Security Group"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP Access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound Access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "lb-sg-${random_string.suffix.result}"
  })
}

resource "aws_security_group" "ecs" {
  name        = "ecs-sg-${random_string.suffix.result}"
  description = "ECS Security Group"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "App Port Access"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.lb.id]
  }

  egress {
    description = "Outbound Access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "ecs-sg-${random_string.suffix.result}"
  })
}

# Load Balancer
resource "aws_lb" "app" {
  name               = "alb-${random_string.suffix.result}"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnets.public.ids
  security_groups    = [aws_security_group.lb.id]
  enable_deletion_protection = false

  tags = merge(local.common_tags, {
    Name = "alb-${random_string.suffix.result}"
  })
}

resource "aws_lb_target_group" "app" {
  name        = "tg-${random_string.suffix.result}"
  port        = var.app_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.default.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = merge(local.common_tags, {
    Name = "tg-${random_string.suffix.result}"
  })
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = merge(local.common_tags, {
    Name = "listener-${random_string.suffix.result}"
  })
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "cluster-${random_string.suffix.result}"

  tags = merge(local.common_tags, {
    Name = "cluster-${random_string.suffix.result}"
  })
}

# IAM Role with Least Privilege
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = merge(local.common_tags, {
    Name = "ecs-role-${random_string.suffix.result}"
  })
}

resource "aws_iam_role_policy" "ecs_logs" {
  name = "logs-access-${random_string.suffix.result}"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "arn:aws:logs:${var.region}:*:log-group:/ecs/task-${random_string.suffix.result}:*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "task-${random_string.suffix.result}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "react-container"
    image     = var.app_image
    essential = true
    portMappings = [{
      containerPort = var.app_port
      hostPort      = var.app_port
    }]
    environment = [{
      name  = "NODE_ENV"
      value = "production"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])

  tags = merge(local.common_tags, {
    Name = "task-${random_string.suffix.result}"
  })
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "svc-${random_string.suffix.result}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "react-container"
    container_port   = var.app_port
  }

  tags = merge(local.common_tags, {
    Name = "svc-${random_string.suffix.result}"
  })
}

# CloudWatch Log Group with Tags
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/task-${random_string.suffix.result}"
  retention_in_days = var.is_temporary ? 1 : 7
  tags              = local.common_tags
}

# Outputs
output "alb_dns_name" {
  description = "Application Load Balancer DNS Name"
  value       = aws_lb.app.dns_name
}

output "ecs_cluster_name" {
  description = "ECS Cluster Name"
  value       = aws_ecs_cluster.main.name
}