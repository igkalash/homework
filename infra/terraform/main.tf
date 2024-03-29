terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-1"
}


resource "aws_instance" "homework" {
  count           = var.ec2_count
  ami             = "ami-0281f4ac130d55502"
  instance_type   = var.ec2_instance_type
  security_groups = [aws_security_group.instances.name]
  key_name        = "homework_key_pair"
  tags = {
    Name = "Server ${count.index + 1}"
  }

}

resource "aws_instance" "homework2" {
  ami           = "ami-0281f4ac130d55502"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.instances.name]
  key_name = "homework_key_pair"
  tags = {
    Name = "homework tag"
  }
}


resource "aws_security_group" "instances" {
  name = "instance-security-group"
}

resource "aws_security_group_rule" "allow_5000_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.instances.id

  from_port   = 5000
  to_port     = 5000
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.instances.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_ssh_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.instances.id

  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.load_balancer.arn

  port = 80

  protocol = "TCP"


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.instances.arn
  }

}

resource "aws_lb_target_group" "instances" {
  name     = "homework-target-group"
  port     = 5000
  protocol = "TCP"
  vpc_id   = data.aws_vpc.default_vpc.id
}



resource "aws_lb_target_group_attachment" "homework" {
  count            = var.ec2_count
  target_group_arn = aws_lb_target_group.instances.arn
  target_id        = aws_instance.homework[count.index].id
  port             = 5000
}


resource "aws_security_group" "alb" {
  name = "alb-security-group"
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id

  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

}

resource "aws_security_group_rule" "allow_alb_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.alb.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

}

data "aws_vpc" "default_vpc" {
  default = true

}


data "aws_subnets" "default_subnets" {

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
}

resource "aws_lb" "load_balancer" {
  name               = "web-app"
  load_balancer_type = "network"
  subnets            = data.aws_subnets.default_subnets.ids
  security_groups    = [aws_security_group.alb.id]

}

data "aws_route53_zone" "primary" {
  name = "homework.systems"

}

resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "homework.systems"
  type    = "A"

  alias {
    name                   = aws_lb.load_balancer.dns_name
    zone_id                = aws_lb.load_balancer.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "homework" {
  count      = var.ec2_count
  zone_id    = data.aws_route53_zone.primary.zone_id
  name       = "host${count.index + 1}.homework.systems"
  type       = "A"
  records    = [aws_instance.homework[count.index].public_ip]
  ttl        = 300
  depends_on = [aws_instance.homework]
}
