provider "aws" {
  region = "us-east-1"
}

# ---------------------------
# Security Group for EC2 / ALB
# ---------------------------
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP and SSH inbound traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------
# Security Group for RDS
# ---------------------------
resource "aws_security_group" "db_sg" {
  name        = "db-sg"
  description = "Allow MySQL access from EC2"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] # only allow traffic from web_sg
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------
# Data sources for default VPC & Subnets
# ---------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ---------------------------
# Launch Template for EC2 instances
# ---------------------------
resource "aws_launch_template" "web" {
  name_prefix   = "web-template-"
  image_id      = "ami-08c40ec9ead489470" # Ubuntu 22.04 LTS
  instance_type = "t2.micro"

  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y apache2 mysql-client
              systemctl enable apache2
              systemctl start apache2
              echo "Hello from $(hostname)" > /var/www/html/index.html
              EOF
  )

  vpc_security_group_ids = [aws_security_group.web_sg.id]
}

# ---------------------------
# Application Load Balancer
# ---------------------------
resource "aws_lb" "web" {
  name               = "web-lb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.web_sg.id]
}

resource "aws_lb_target_group" "web_tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# ---------------------------
# Auto Scaling Group (2 instances, can scale)
# ---------------------------
resource "aws_autoscaling_group" "web_asg" {
  desired_capacity     = 2
  max_size             = 3
  min_size             = 2
  vpc_zone_identifier  = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.web_tg.arn]

  depends_on = [aws_lb_listener.http]
}

# ---------------------------
# RDS MySQL Database
# ---------------------------
resource "aws_db_instance" "mysql" {
  identifier          = "mydb"
  allocated_storage   = 20
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = "db.t3.micro"
  username            = "admin"
  password            = "Admin1234!"   # use Terraform variables or Secrets Manager in production
  skip_final_snapshot = true

  vpc_security_group_ids = [aws_security_group.db_sg.id]

  publicly_accessible = false   # only EC2 can connect
}

# ---------------------------
# Outputs
# ---------------------------
output "lb_dns_name" {
  value = aws_lb.web.dns_name
}

output "db_endpoint" {
  value = aws_db_instance.mysql.endpoint
}
