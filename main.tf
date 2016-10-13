resource "aws_instance" "web" {
  ami           = "${lookup(var.ami, var.region)}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_name}"
  subnet_id     = "${element(module.vpc.public_subnet_ids, 0)}"
  user_data     = "${file("files/web_bootstrap.sh")}"
  vpc_security_group_ids = [
    "${aws_security_group.web_host_sg.id}"
  ]
  tags {
    Name = "${var.environment}-web-${count.index}"
  }
  count = 2
}

resource "aws_elb" "web" {
  name                = "${var.environment}-web-elb"
  subnets             = ["${element(module.vpc.public_subnet_ids, 0)}"]
  security_groups     = ["${aws_security_group.web_inbound_sg.id}"]
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  instances = ["${aws_instance.web.*.id}"]
}

resource "aws_instance" "app" {
  ami           = "${lookup(var.ami, var.region)}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_name}"
  subnet_id     =  "${element(module.vpc.private_subnet_ids, 0)}"
  user_data     = "${file("files/app_bootstrap.sh")}"
  vpc_security_group_ids = [
    "${aws_security_group.app_host_sg.id}",
  ]
  tags {
    Name = "${var.environment}-app-${count.index}"
  }
  count = 2
}

resource "aws_security_group" "web_inbound_sg" {
  name        = "${var.environment}-web_inbound"
  description = "Allow HTTP from Anywhere"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web_host_sg" {
  name        = "${var.environment}-web_host"
  description = "Allow SSH & HTTP to web hosts"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${module.vpc.vpc_cidr}"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${module.vpc.vpc_cidr}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app_host_sg" {
  name        = "${var.environment}-app_host"
  description = "Allow App traffic to app hosts"
  vpc_id      = "${module.vpc.vpc_id}"

  # App access from the VPC
  ingress {
    from_port   = 1234
    to_port     = 1234
    protocol    = "tcp"
    cidr_blocks = ["${module.vpc.vpc_cidr}"]
  }

  # SSH access from the VPC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${module.vpc.vpc_cidr}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
