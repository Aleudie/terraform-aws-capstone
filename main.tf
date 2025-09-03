provider "aws" {
  region = "us-east-1"
}

# ---------------------------
# Security Group for the EC2
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
# Security Group for the DB
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
# EC2 Instance
# ---------------------------
resource "aws_instance" "web" {
  ami           = "ami-08c40ec9ead489470" # Ubuntu 22.04 LTS (us-east-1)
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y apache2 mysql-client
              systemctl enable apache2
              systemctl start apache2
              echo "Hello from $(hostname)" > /var/www/html/index.html
              EOF

  tags = {
    Name = "terraform-apache-vm"
  }
}

# ---------------------------
# RDS MySQL Database
# ---------------------------
resource "aws_db_instance" "mysql" {
  identifier        = "mydb"
  allocated_storage = 20
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  username          = "admin"
  password          = "Admin1234!"   # better to use Terraform variables or AWS Secrets Manager
  skip_final_snapshot = true

  vpc_security_group_ids = [aws_security_group.db_sg.id]

  publicly_accessible = false   # best practice, only EC2 can connect
}

# ---------------------------
# Outputs
# ---------------------------
output "public_ip" {
  value = aws_instance.web.public_ip
}

output "web_url" {
  value = "http://${aws_instance.web.public_ip}"
}

output "db_endpoint" {
  value = aws_db_instance.mysql.endpoint
}
