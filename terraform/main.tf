provider "aws" {
  region = var.region
}

provider "random" {}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
  numeric = true
}

# Usar VPC padrão existente
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

# Internet Gateway (já existe na VPC padrão)
data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Route Table (já existe na VPC padrão)
data "aws_route_table" "public" {
  vpc_id = data.aws_vpc.default.id
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

# Security Group para o ALB
resource "aws_security_group" "lb" {
  name   = "lb-sg-${random_string.suffix.result}"
  vpc_id = data.aws_vpc.default.id

  ingress {
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
    Name = "lb-sg-${random_string.suffix.result}"
  }
}

# Security Group para o ECS
resource "aws_security_group" "ecs" {
  name   = "ecs-sg-${random_string.suffix.result}"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.lb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-sg-${random_string.suffix.result}"
  }
}

# Application Load Balancer
resource "aws_lb" "app" {
  name               = "alb-${random_string.suffix.result}"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnets.public.ids
  security_groups    = [aws_security_group.lb.id]
  enable_deletion_protection = false

  timeouts {
    create = "10m"
    delete = "10m"
  }

  tags = {
    Name = "alb-${random_string.suffix.result}"
  }
}

# Target Group
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

  tags = {
    Name = "tg-${random_string.suffix.result}"
  }
}

# Listener do ALB
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = {
    Name = "listener-${random_string.suffix.result}"
  }
}

# Cluster ECS
resource "aws_ecs_cluster" "main" {
  name = "cluster-${random_string.suffix.result}"

  tags = {
    Name = "cluster-${random_string.suffix.result}"
  }
}

# IAM Role para execução de tarefas
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

  tags = {
    Name = "ecs-role-${random_string.suffix.result}"
  }
}

# Política com permissões completas para CloudWatch Logs
resource "aws_iam_role_policy" "ecs_logs_full" {
  name = "logs-full-access-${random_string.suffix.result}"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "logs:*"  # Permissão ampla temporária
      ]
      Resource = "*"
    }]
  })
}

# DEPOIS adicionamos a política padrão
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Definition
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
    cpu       = 256
    memory    = 512
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
        awslogs-group         = "/ecs/task-${random_string.suffix.result}"
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])

  tags = {
    Name = "task-${random_string.suffix.result}"
  }
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

  depends_on = [
    aws_lb_listener.front_end,
    aws_iam_role_policy.ecs_logs_full
  ]

  tags = {
    Name = "svc-${random_string.suffix.result}"
  }
}

# CloudWatch Log Group (SEM TAGS)
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/task-${random_string.suffix.result}"
  retention_in_days = 1
}