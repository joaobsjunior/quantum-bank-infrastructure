provider "aws" {
  region = var.aws_region
}

module "runtime" {
  source = "../modules/runtime-conventions"

  project_name     = var.project_name
  environment      = var.environment
  container_images = var.container_images
  common_tags      = var.common_tags
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_ecs_cluster" "runtime" {
  name = module.runtime.name_prefix
  tags = module.runtime.tags
}

resource "aws_cloudwatch_log_group" "service" {
  for_each = module.runtime.services

  name              = "/quantum-bank/${var.environment}/${each.value.name}"
  retention_in_days = 30
  tags              = module.runtime.tags
}

resource "aws_iam_role" "task_execution" {
  name               = "${module.runtime.name_prefix}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  tags               = module.runtime.tags
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "service" {
  for_each = module.runtime.services

  family                   = "${module.runtime.name_prefix}-${each.value.name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([
    {
      name      = each.value.name
      image     = each.value.image
      essential = true
      portMappings = [
        {
          containerPort = each.value.port
          hostPort      = each.value.port
          protocol      = "tcp"
        }
      ]
      environment = [
        for name, value in var.runtime_environment : {
          name  = name
          value = value
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.service[each.key].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = each.value.name
        }
      }
    }
  ])

  tags = module.runtime.tags
}

resource "aws_ecs_service" "service" {
  for_each = module.runtime.services

  name            = each.value.name
  cluster         = aws_ecs_cluster.runtime.id
  task_definition = aws_ecs_task_definition.service[each.key].arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  tags = module.runtime.tags
}
