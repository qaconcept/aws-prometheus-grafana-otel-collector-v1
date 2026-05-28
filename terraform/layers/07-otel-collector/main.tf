# layers/07-otel-collector/main.tf

resource "aws_service_discovery_service" "otel" {
  name = "otel"
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

resource "aws_ecs_task_definition" "otel" {
  family                   = "${var.project_name}-otel"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([{
    name  = "otel-collector"
    image = "public.ecr.aws/aws-observability/aws-otel-collector:v0.40.0" 
    
    portMappings = [
      { containerPort = 4317, hostPort = 4317, protocol = "tcp" }, # OTLP gRPC 
      { containerPort = 4318, hostPort = 4318, protocol = "tcp" }, # OTLP HTTP 
      { containerPort = 8888, hostPort = 8888, protocol = "tcp" }, # Metrics Engine
      { containerPort = 13133, hostPort = 13133, protocol = "tcp" } # ADDED: Internal Health Extension Port
    ]

    # NATIVE HEALTHCHECK (Uses the pre-compiled binary instead of wget/shell)
    healthCheck = {
      command     = ["CMD", "/healthcheck"]
      interval    = 15
      timeout     = 5
      retries     = 3
      startPeriod = 15
    }

    environment = [
      {
        name  = "AOT_CONFIG_CONTENT"
        value = <<EOF
extensions:
  health_check:
    endpoint: 0.0.0.0:13133

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
  
  # Internal collector scraper
  prometheus:
    config:
      scrape_configs:
        - job_name: 'otel-collector'
          scrape_interval: 10s
          static_configs:
            - targets: ['0.0.0.0:8888']
  
  # PHASE 4 ADDITION: Free local Fargate resource scraper
  awsecscontainermetrics:
    collection_interval: 20s

exporters:
  otlp/jaeger:
    endpoint: "jaeger.$${var.domain_name}:443"
    tls:
      insecure: false
  
  # Pushes metric telemetry upstream to your Prometheus cluster
  prometheusremotewrite:
    endpoint: "http://prometheus.$${var.project_name}.internal:9090/api/v1/write"
    tls:
      insecure: true
  
  logging:
    verbosity: detailed

service:
  extensions: [health_check]
  pipelines:
    traces:
      receivers: [otlp]
      processors: []
      exporters: [otlp/jaeger, logging]
    
    # FIXED & ACTIVATED: Metrics pipeline routing everything to Prometheus
    metrics:
      receivers: [prometheus, awsecscontainermetrics]
      processors: []
      exporters: [prometheusremotewrite]
EOF
      }
    ]

    logConfiguration = {
      logDriver = "awslogs" 
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.aws_region 
        "awslogs-stream-prefix" = "otel" 
      }
    }
  }])
}

resource "aws_ecs_service" "otel" {
  name            = "otel-collector-service"
  cluster         = var.ecs_cluster_id 
  task_definition = aws_ecs_task_definition.otel.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.otel.arn
  }
}