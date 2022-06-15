terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
  access_key = "AKIAXJRZU6J2EHKR27W4"
  secret_key = "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"
}

resource "aws_instance" "app_server" {
  ami           = "ami-06eecef118bbf9259"
  instance_type = "t2.micro"
  key_name= "aws_key_1"

  tags = {
    Name = "app_2"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "aws_key_1"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC5e+7m+vSqJbvLfa4eB4/awmIDjzBw9Wbs24OoFM36xXq8VZ+to42sDbh+l7hcor90dOzoMwJsiMhDYlWpHwjAcOMqgcjyUI6pvBdKEnu75kqxUdx6KlsQ/lEoR/haoM47jJKV+S8tJs90pxmTfTIFyGwcpeh/Ed7iliJ9MIF3hpmwxSPea/mBdl1mKeSDFzOvTwI2LvShkTFc4RxfVPaqGVql5u42N2eK40b04/pBfQ/8/vDSunfRPzyTbPlhyoLvqjyilM7vrS1eBI3suEZ8/AQOnEXcuZLFhRSMWM5hormKn/y4aL3IbuCUq0dK7HPkYlkxoeVzm9BP6yaqjfnlNHIm6KT0HJ+RiqgimjacR0KQsfbrmja6LBTz/1AYjs35Wx2V2IJarTMEWw4LIOuliMWevP5cPQAhtO5IgSjthRK2MSmCqhAc8T/Dr0WpDoI2yoTNwR27GPC8KgE4Crwa/X6RFj620xC3/EoBd5sxjZsJUXnLs1cTsvvVT+5uDrs= aditya@DESKTOP-OHEGJUU"
}

resource "aws_security_group" "alb" {
  name        = "terraform_alb_security_group"
  description = "Terraform load balancer security group"
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = "${var.allowed_cidr_blocks}"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = "${var.allowed_cidr_blocks}"
  }

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-example-alb-security-group"
  }
}

resource "aws_alb" "alb" {
  name            = "terraform-example-alb"
  security_groups = ["${aws_security_group.alb.id}"]
  subnets         = ["${aws_subnet.main.*.id}"]
  tags = {
    Name = "terraform-example-alb"
  }
}

resource "aws_alb_target_group" "group" {
  name     = "terraform-example-alb-target"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.vpc.id}"
  stickiness {
    type = "lb_cookie"
  }
  # Alter the destination of the health check to be the login page.
  health_check {
    path = "/login"
    port = 80
  }
}

resource "aws_alb_listener" "listener_http" {
  load_balancer_arn = "${aws_alb.alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.group.arn}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "listener_https" {
  load_balancer_arn = "${aws_alb.alb.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${var.certificate_arn}"
  default_action {
    target_group_arn = "${aws_alb_target_group.group.arn}"
    type             = "forward"
  }
}

resource "aws_route53_record" "terraform" {
  zone_id = "${data.aws_route53_zone.zone.zone_id}"
  name    = "terraform.${var.route53_hosted_zone_name}"
  type    = "A"
  alias {
    name                   = "${aws_alb.alb.dns_name}"
    zone_id                = "${aws_alb.alb.zone_id}"
    evaluate_target_health = true
  }
}

