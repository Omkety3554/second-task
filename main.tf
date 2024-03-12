#aunthenticate with aws
provider "aws" {
  region = "us-east-1"
  access_key = 
  secret_key = 
}


# Create a VPC

resource "aws_vpc" "prodvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "production_vpc"
  }
}

# Create a public Subnet

resource "aws_subnet" "prod_public_subnet" {
  vpc_id            = aws_vpc.prodvpc.id
  cidr_block        = "10.0.102.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "prod-public-subnet"
  }
}

# Create a private Subnet

resource "aws_subnet" "prod_private_subnet" {
  vpc_id            = aws_vpc.prodvpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "prod-private-subnet"
  }
}


#Create Internet Gateway for public subnet
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prodvpc.id

  tags = {
    Name = "igw"
  }
}



#Create elastic ip for NAT 
resource "aws_eip" "nat_eip" {

depends_on = [ aws_internet_gateway.gw ]

  
}

#Create Nat Gateway for private subnet
resource "aws_nat_gateway" "NAT" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.prod_private_subnet.id
  depends_on = [ aws_internet_gateway.gw ]
  
  tags = {
    Name = "nat"
  }
}


# Create a Route Table for public internet gateway
resource "aws_route_table" "public-internet-gateway" {
  vpc_id = aws_vpc.prodvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "RT"
  }
}

# Create a Route Table for private nat gateway
resource "aws_route_table" "private-nat-gatewway" {
  vpc_id = aws_vpc.prodvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NAT.id
  }

  tags = {
    Name = "RT"
  }
}


#Associate subnet with Route Table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.prod_public_subnet.id
  route_table_id = aws_route_table.public-internet-gateway.id
}

#Associate subnet with Route Table
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.prod_private_subnet.id
  route_table_id = aws_route_table.private-nat-gatewway.id
}

# Create a Security Group
resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow webserver inbound traffic"
  vpc_id      = aws_vpc.prodvpc.id

  ingress {
    description = "Web Traffic from VPC" 
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    description = "HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1" # Any ip address/ any protocol
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

#create a load balancer

#Create Application Load Balancer's target group
resource "aws_alb_target_group" "alb_targer_grp" {
  name     = "alb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.prodvpc.id
  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 3
  }
}

#Create Application Load Balancer target group attachment
resource "aws_lb_target_group_attachment" "attach-instance01" {
  target_group_arn = aws_alb_target_group.alb_targer_grp.arn
  target_id        = aws_instance.secondinstance.id
  port             = 80
}

# Create Application load balancer listner 
resource "aws_lb_listener" "web_alb_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.alb_targer_grp.arn
  }
}

#Create Application Load Balancer 
resource "aws_lb" "web_alb" {
  name                       = "web-loadbalancer"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.allow_web.id]
  subnets                    = [aws_subnet.prod_public_subnet.id,aws_subnet.prod_private_subnet.id]
  enable_deletion_protection = false
  tags = {
    Environment = "Test"

  }
}


output "load_balancer_dns_name" {
  description = "Get load balancer name"
  value = aws_lb.web_alb.dns_name
}


#create ec2 instances
resource "aws_instance" "firstinstance" {
  ami                    = "ami-07d9b9ddc6cd8dd30"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_web.id]
  subnet_id              = aws_subnet.prod_public_subnet.id
  key_name               = "Taskkp"
  availability_zone      = "us-east-1a"
  user_data              =  "${file("install_jenkins.sh")}"


  tags = {
    Name = "Jenkins_Server"
  } 
}


resource "aws_instance" "secondinstance" {
  ami                    = "ami-07d9b9ddc6cd8dd30"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_web.id]
  subnet_id              = aws_subnet.prod_private_subnet.id
  key_name               = "Taskkp"
  availability_zone      = "us-east-1b"
  user_data              =  "${file("install_tomcat.sh")}"
  


  tags = {
    Name = "Tomcat_Server"
  }
}

# use data source to get a registered ubuntu ami
data "aws_ami" "ubuntu" {

  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

# print the url of the jenkins server
output "Jenkins_website_url" {
  value     = join ("", ["http://", aws_instance.firstinstance.public_ip, ":", "8080"])
  description = "Jenkins Server is firstinstance"
}

# print the url of the tomcat server
output "Tomcat_website_url1" {
  value     = join ("", ["http://", aws_instance.secondinstance.public_ip, ":", "8080"])
  description = "Tomcat Server is secondinstance"
}

#output "website-url" {
 # value       = "${aws_instance.firstinstance.*.public_ip}"
  #description = "PublicIP address details"
#}
# aws_instance.ec2_instance.public_dns
