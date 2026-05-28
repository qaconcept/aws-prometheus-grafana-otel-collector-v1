# layers/06-alb/main.tf

# ==============================================================================
# 1. CORE APPLICATION LOAD BALANCER DEFINITION
# ==============================================================================
resource "aws_lb" "main" {
  name               = "obs-v1-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids
}

# ==============================================================================
# 2. TARGET GROUPS
# ==============================================================================

resource "aws_lb_target_group" "grafana" {
  name        = "obs-v1-grafana-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check { path = "/api/health" }
}

# TARGET GROUP 1: Dedicated to Jaeger Live Telemetry Streams (gRPC)
resource "aws_lb_target_group" "jaeger_grpc" {
  name_prefix      = "jg-rpc"
  port             = 4317
  protocol         = "HTTP"
  vpc_id           = var.vpc_id
  target_type      = "ip"
  protocol_version = "GRPC" # Handles multiplexed binary frames natively

  # FIXED HEALTH CHECK: Probe the native gRPC receiver directly
  health_check {
    protocol            = "HTTP"
    port                = "4317"                            # Target the actual gRPC port
    path                = "/aws.cdc.NonExistentService/Probe" # Structural dummy path for gRPC probe
    matcher             = "12"                              # 12 = gRPC UNIMPLEMENTED (Confirms gRPC engine is listening)
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  lifecycle {
    create_before_destroy = true
  }
}

# TARGET GROUP 2: Dedicated to Jaeger Web UI (Standard HTTP)
resource "aws_lb_target_group" "jaeger_ui" {
  name_prefix      = "jg-ui"
  port             = 16686
  protocol         = "HTTP"
  vpc_id           = var.vpc_id
  target_type      = "ip"

  # FIXED HEALTH CHECK: Probe the Admin interface on Port 14269 using standard HTTP/1.1
  health_check {
    protocol            = "HTTP"
    port                = "14269" # Standard HTTP probe against the Admin interface
    path                = "/"      
    matcher             = "200"   # Returns standard HTTP 200 OK
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# 3. HTTPS LISTENER
# ==============================================================================
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Host Not Found"
      status_code  = "404"
    }
  }
}

# ==============================================================================
# 4. HOST & PATH-BASED ROUTING RULES
# ==============================================================================

resource "aws_lb_listener_rule" "grafana" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }

  condition {
    host_header {
      values = ["grafana.${var.domain_name}"]
    }
  }
}

# Rule 2: Intercept & Forward gRPC Telemetry Traffic
resource "aws_lb_listener_rule" "jaeger_grpc" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 190 # Higher priority to catch streaming traffic before the fallback rule

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jaeger_grpc.arn
  }

  condition {
    host_header {
      values = ["jaeger.${var.domain_name}"]
    }
  }

  condition {
    path_pattern {
      values = ["/opentelemetry.proto.*", "/jaeger.api.*"]
    }
  }
}

# Rule 3: Fallback to Jaeger Web UI
resource "aws_lb_listener_rule" "jaeger_ui" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jaeger_ui.arn
  }

  condition {
    host_header {
      values = ["jaeger.${var.domain_name}"]
    }
  }
}

# ==============================================================================
# 5. ROUTE 53 AUTOMATIC SUBDOMAIN MAPPING
# ==============================================================================
data "aws_route53_zone" "primary" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "grafana" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "grafana.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "jaeger" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "jaeger.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}