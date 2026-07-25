# 1. ALB Security Group (Public facing)
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Controls HTTP/HTTPS traffic to the Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description      = "Allow HTTP from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "Allow HTTPS from anywhere"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-alb-sg"
    }
  )
}

# 2. Application Security Group (EC2 Instances in Private App Subnets)
resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app-sg"
  description = "Controls traffic to EC2 app instances (Strictly allowed from ALB only)"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow app port traffic strictly from ALB Security Group"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description      = "Allow outbound internet egress for package updates & SSM"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-app-sg"
    }
  )
}

# 3. Database Security Group (RDS in Isolated Data Subnets)
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Controls traffic to RDS MySQL (Strictly allowed from App Security Group only)"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow MySQL traffic strictly from App Security Group"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    description = "No outbound connection allowed from Database Tier"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rds-sg"
    }
  )
}
