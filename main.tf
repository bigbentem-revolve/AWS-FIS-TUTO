###############################
# VPC + Subnets
###############################
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "${local.prefix}-chaos-vpc" }
}


resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.prefix}-public-a" }
}


resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.prefix}-public-b" }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.prefix}-main-igw" }
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${local.prefix}-public-rt" }
}


resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}


resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}


###############################
# Security Groups
###############################
resource "aws_security_group" "alb_sg" {
  name        = "${local.prefix}-alb-sg"
  description = "Allow HTTP from anywhere"
  vpc_id      = aws_vpc.main.id


  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = { Name = "${local.prefix}-alb-sg" }
}


resource "aws_security_group" "ec2_sg" {
  name        = "${local.prefix}-ec2-sg"
  description = "Allow HTTP from ALB"
  vpc_id      = aws_vpc.main.id


  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = { Name = "${local.prefix}-ec2-sg" }
}


resource "aws_security_group" "rds_sg" {
  name        = "${local.prefix}-rds-sg"
  description = "Allow MySQL/Postgres from EC2"
  vpc_id      = aws_vpc.main.id


  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = { Name = "${local.prefix}-rds-sg" }
}


###############################
# ALB + Target Group
###############################
resource "aws_lb" "web_alb" {
  name               = "${local.prefix}-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  tags               = { Name = "${local.prefix}-web-alb" }
}


resource "aws_lb_target_group" "web_tg" {
  name        = "${local.prefix}-web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }
  tags = { Name = "${local.prefix}-web-tg" }
}


resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}


###############################
# Launch Template pour ASG
###############################
resource "aws_launch_template" "web_lt" {
  name_prefix            = "${local.prefix}-web-lt-"
  image_id               = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.ec2_keypair.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(file("./userdata.sh"))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${local.prefix}-web-instance"
      Service     = "web"
      Environment = "staging"
    }
  }
  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${local.prefix}-web-volume"
      Service     = "web"
      Environment = "staging"
    }
  }
}


###############################
# Auto Scaling Group
###############################
resource "aws_autoscaling_group" "web_asg" {
  desired_capacity    = 2
  min_size            = 1
  max_size            = 3
  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.web_tg.arn]


  tag {
    key                 = "Service"
    value               = "web"
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = "staging"
    propagate_at_launch = true
  }
}


###############################
# RDS instance
###############################
resource "aws_db_subnet_group" "rds_subnets" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}


resource "aws_db_instance" "web_rds" {
  identifier                  = "${local.prefix}-web-db"
  allocated_storage           = 20
  engine                      = "mysql" # ou "postgres"
  engine_version              = "8.0"
  instance_class              = "db.t3.micro"
  db_name                     = "webdb"
  username                    = "admin"
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids      = [aws_security_group.rds_sg.id]
  skip_final_snapshot         = true
  publicly_accessible         = false
  multi_az                    = false
  tags = {
    Name        = "${local.prefix}-web-rds"
    Service     = "web"
    Environment = "staging"
  }
}