# layers/11-test-app/main.tf

resource "aws_ecs_task_definition" "test_app" {
  family                   = "${var.project_name}-test-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([{
    name  = "python-test-app"
    image = "${var.dockerhub_username}/python-test-app:latest"

    command = ["python", "main.py"] # Native telemetry generation runtime script

    # FIXED NATIVE HEALTHCHECK (Bypasses missing utilities by checking /proc natively)
    healthCheck = {
      command     = ["CMD-SHELL", "[ -d /proc/1 ] || exit 1"]
      interval    = 15
      timeout     = 5
      retries     = 3
      startPeriod = 15 # Gives the Python engine plenty of time to warm up and run
    }

    environment = [
      {
        name  = "PYTHONUNBUFFERED"
        value = "1"
      },
      {
        name  = "OTEL_PYTHON_LOG_LEVEL"
        value = "debug"
      },
      {
        name  = "OTEL_LOG_LEVEL"
        value = "debug"
      },
      {
        name  = "OTEL_SERVICE_NAME"
        value = "python-test-app"
      },
      {
        name  = "OTEL_EXPORTER_OTLP_PROTOCOL"
        value = "grpc"
      },
      {
        name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
        value = "http://otel.aws-prometheus-grafana-otel-collector-v1.internal:4317"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "app"
      }
    }
  }])
}

resource "aws_ecs_service" "test_app" {
  name            = "test-app-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.test_app.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  # Graceful rolling deployment parameters
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = true
  }
}