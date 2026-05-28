# layers/10-grafana/main.tf

resource "aws_service_discovery_service" "grafana" {
  name = "grafana"
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

resource "aws_ecs_task_definition" "grafana" {
  family                   = "${var.project_name}-grafana"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  volume {
    name = "grafana-data"
    efs_volume_configuration {
      file_system_id     = var.efs_file_system_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = var.grafana_ap_id
        iam             = "DISABLED"
      }
    }
  }

  container_definitions = jsonencode([{
    name  = "grafana" 
    image = "grafana/grafana:latest" 
    environment = [
      { name = "GF_SERVER_DOMAIN", value = "grafana.${var.domain_name}" }, 
      { name = "GF_SERVER_ROOT_URL", value = "https://grafana.${var.domain_name}/" }, 
      { name = "GF_SERVER_SERVE_FROM_SUB_PATH", value = "false" } 
    ]
    portMappings = [
      { containerPort = 3000, hostPort = 3000, protocol = "tcp" } 
    ]
    
    # NATIVE ECS HEALTHCHECK
    healthCheck = {
      command     = ["CMD-SHELL", "wget --spider -q http://localhost:3000/api/health || exit 1"]
      interval    = 15
      timeout     = 5
      retries     = 3
      startPeriod = 20  # Gives Grafana extra time to initialize SQLite/EFS migrations before checking
    }

    mountPoints = [
      {
        sourceVolume  = "grafana-data"
        containerPath = "/var/lib/grafana"
        readOnly      = false
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "grafana"
      }
    }
  }])
}

resource "aws_ecs_service" "grafana" {
  name            = "grafana-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.grafana.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.grafana_tg_arn
    container_name   = "grafana"
    container_port   = 3000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.grafana.arn
  }
}