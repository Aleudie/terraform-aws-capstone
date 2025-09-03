provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "web" {
  ami           = "ami-08c40ec9ead489470" # Amazon Linux 2 AMI (update if needed per region)
  instance_type = "t2.micro"

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl enable httpd
              systemctl start httpd
              echo "Hello from $(hostname)" > /var/www/html/index.html
              EOF

  tags = {
    Name = "terraform-apache-vm"
  }
}

output "public_ip" {
  value = aws_instance.web.public_ip
}

output "web_url" {
  value = "http://${aws_instance.web.public_ip}"
}
