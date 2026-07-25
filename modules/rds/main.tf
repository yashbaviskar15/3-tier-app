# 1. Random Password Generation if not provided
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

locals {
  db_password = var.password != "" ? var.password : random_password.db_password.result
}

# 2. KMS Key for DB Storage Encryption
resource "aws_kms_key" "rds" {
  description             = "KMS Key for RDS MySQL Encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rds-kms-key"
    }
  )
}

# 3. DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = var.private_data_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-db-subnet-group"
    }
  )
}

# 4. DB Parameter Group
resource "aws_db_parameter_group" "main" {
  name   = "${var.name_prefix}-mysql-params"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  parameter {
    name  = "max_connections"
    value = "500"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-mysql-params"
    }
  )
}

# 5. RDS MySQL Instance
resource "aws_db_instance" "main" {
  identifier            = "${var.name_prefix}-mysql"
  engine                = "mysql"
  engine_version        = var.engine_version
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  db_name  = var.db_name
  username = var.username
  password = local.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  parameter_group_name   = aws_db_parameter_group.main.name

  multi_az            = var.multi_az
  publicly_accessible = false
  skip_final_snapshot = true

  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  deletion_protection     = var.deletion_protection

  auto_minor_version_upgrade = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-mysql-db"
    }
  )
}

# 6. AWS Secrets Manager Secret for DB Credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.name_prefix}-db-credentials"
  description             = "Database master credentials for ${var.name_prefix} RDS MySQL"
  recovery_window_in_days = 0

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-db-credentials"
    }
  )
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    engine   = "mysql"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
    username = var.username
    password = local.db_password
  })
}
