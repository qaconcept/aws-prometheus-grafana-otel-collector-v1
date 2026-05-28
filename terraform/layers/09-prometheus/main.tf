# layers/09-prometheus/main.tf

resource "aws_service_discovery_service" "prometheus" {
  name = "prometheus"
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

resource "aws_ecs_task_definition" "prometheus" {
  family                   = "${var.project_name}-prometheus"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  volume {
    name = "prometheus-data"
    efs_volume_configuration {
      file_system_id     = var.efs_file_system_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = var.prometheus_ap_id
        iam             = "DISABLED" 
      }
    }
  }

  container_definitions = jsonencode([{
    name  = "prometheus"
    image = "prom/prometheus:latest"
    
    # 1. Instruct Fargate to open a shell runtime environment on boot
    entryPoint = ["sh", "-c"]
    
    # 2. Inject the custom prometheus.yml config and execute the server binary
    command = [
      <<-EOT
      cat << 'EOF' > /tmp/prometheus.yml
      global:
        scrape_interval: 15s
        evaluation_interval: 15s

      scrape_configs:
        - job_name: 'prometheus'
          static_configs:
            - targets: ['localhost:9090']

        - job_name: 'otel-collector'
          dns_sd_configs:
            - names: ['otel.${var.project_name}.internal']
              type: 'A'
              port: 8888
      EOF
      /bin/prometheus --config.file=/tmp/prometheus.yml --storage.tsdb.path=/prometheus
      EOT
    ]

    portMappings = [
      { containerPort = 9090, hostPort = 9090, protocol = "tcp" }
    ]

    healthCheck = {
      command     = ["CMD-SHELL", "wget --spider -q http://localhost:9090/-/healthy || exit 1"]
      interval    = 15
      timeout     = 5
      retries     = 3
      startPeriod = 15 
    }

    mountPoints = [
      {
        sourceVolume  = "prometheus-data"
        containerPath = "/prometheus"
        readOnly      = false
      }
    ]
    
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "prometheus"
      }
    }
  }])
}

resource "aws_ecs_service" "prometheus" {
  name            = "prometheus-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.prometheus.arn
  launch_type     = "FARGATE"

  desired_count                      = 1
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.prometheus.arn
  }
}