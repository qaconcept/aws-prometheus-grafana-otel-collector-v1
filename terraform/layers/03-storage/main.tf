# 1. Keep the original CloudWatch Log Group
resource "aws_cloudwatch_log_group" "observability" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7
}

# 2. EFS Security Group (Allows NFS port 2049 ONLY from ECS Tasks)
resource "aws_security_group" "efs" {
  name   = "${var.project_name}-efs-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [var.ecs_sg_id]
    description     = "Allow NFS from ECS Fargate tasks"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. The Core File System (FinOps: Bursting throughput is cheap/free-tier eligible)
resource "aws_efs_file_system" "main" {
  creation_token = "${var.project_name}-efs"
  encrypted      = true
  
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS" # FinOps: Move cold TSDB data to cheaper storage
  }

  tags = { Name = "${var.project_name}-efs" }
}

# 4. Multi-AZ Mount Targets (Ensures HA across all AZs defined in Layer 01)
resource "aws_efs_mount_target" "ecs_mounts" {
  count           = length(var.public_subnet_ids)
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.public_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

# 5. Access Point: Prometheus (Runs as user nobody: 65534)
resource "aws_efs_access_point" "prometheus" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = 65534
    uid = 65534
  }

  root_directory {
    path = "/prometheus"
    creation_info {
      owner_gid   = 65534
      owner_uid   = 65534
      permissions = "755"
    }
  }
}

# 6. Access Point: Grafana (Runs as user grafana: 472)
resource "aws_efs_access_point" "grafana" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = 0
    uid = 472
  }

  root_directory {
    path = "/grafana"
    creation_info {
      owner_gid   = 0
      owner_uid   = 472
      permissions = "755"
    }
  }
}