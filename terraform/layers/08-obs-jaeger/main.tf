resource "aws_service_discovery_service" "jaeger" {
  name = "jaeger"
  dns_config {
    namespace_id = var.cloudmap_namespace_id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "jaeger" {
  family                   = "${var.project_name}-jaeger"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([{
    name  = "jaeger"
    image = "jaegertracing/all-in-one:latest"
    environment = [
      { name = "SPAN_STORAGE_TYPE", value = "memory" }
    ]
    portMappings = [
      { containerPort = 16686, hostPort = 16686, protocol = "tcp" }, # UI Port (Routed via ALB)
      { containerPort = 4317, hostPort = 4317, protocol = "tcp" },   # OTLP gRPC Receiver
      { containerPort = 4318, hostPort = 4318, protocol = "tcp" },    # OTLP HTTP Receiver

      # ADD THIS LINE TO EXPOSE THE HEALTH CHECK PORT TO THE ALB:
      { containerPort = 14269, hostPort = 14269, protocol = "tcp" }  # Admin/Health Port
    ]

    # ADD THIS NATIVE HEALTHCHECK TO TURN THE ECS COLUMN GREEN:
    healthCheck = {
      command     = ["CMD-SHELL", "wget --spider -q http://localhost:14269/ || exit 1"]
      interval    = 15
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }
    
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "jaeger"
      }
    }
  }])
}

resource "aws_ecs_service" "jaeger" {
  name            = "jaeger-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.jaeger.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = true
  }

  # Map the Web UI Traffic to Port 16686
  load_balancer {
    target_group_arn = var.jaeger_ui_tg_arn
    container_name   = "jaeger"
    container_port   = 16686
  }

  # Map the OTLP gRPC Streams to Port 4317
  load_balancer {
    target_group_arn = var.jaeger_grpc_tg_arn
    container_name   = "jaeger"
    container_port   = 4317
  }

  service_registries {
    registry_arn = aws_service_discovery_service.jaeger.arn
  }
}