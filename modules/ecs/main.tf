terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}


resource "aws_ecs_cluster" "cluster" {
  name = "${var.name}-cluster"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "${var.name}/ecs/container-logs"
  retention_in_days = 7
}


resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecsTaskExecutionRoleTf"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_ecs_task_definition" "task_definition" {
  family                   = "${var.name}-task-definition"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  container_definitions = jsonencode([for container in var.container_definitions : {
    name  = container.name
    image = container.image
    "logConfiguration" = {
      "logDriver" : "awslogs",
      "options" : {
        "awslogs-group" : "${aws_cloudwatch_log_group.ecs_logs.name}",
        "awslogs-region" : var.region,
        "awslogs-stream-prefix" : container.name
      }
    }
    essential = lookup(container, "essential", false)
    portMappings = [{
      containerPort = container.ports[0] != null ? container.ports[0] : null,
      hostPort      = container.ports[1] != null ? container.ports[1] : null
    }]
    environment = container.environment != null ? [for key, value in container.environment : {
      name  = key
      value = value
    }] : null
  }])
  memory             = var.memory
  cpu                = var.cpu
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_ecs_service" "app_service" {
  name            = "${var.name}-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task_definition.arn
  launch_type     = "FARGATE"
  desired_count   = var.service_count # Set up the number of containers

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = var.load_balancer.container_name
    container_port   = var.load_balancer.port
  }


  network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}"]
    assign_public_ip = true                                                # Provide the containers with public IPs
    security_groups  = ["${aws_security_group.service_security_group.id}"] # Set up the security group
  }
}
