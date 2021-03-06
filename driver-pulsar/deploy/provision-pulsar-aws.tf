variable "public_key_path" {
  description = <<DESCRIPTION
Path to the SSH public key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.

Example: ~/.ssh/terraform.pub
DESCRIPTION
}

variable "key_name" {
  default = "pulsar-benchmark-key"
  description = "Desired name of AWS key pair"
}

variable "region" {
    default = "us-west-2"
}

variable "ami" {
    default = "ami-9fa343e7" // RHEL-7.4
}

provider "aws" {
    region     = "${var.region}"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "benchmark_vpc" {
  cidr_block = "10.0.0.0/16"

  tags {
      Name = "Benchmark-VPC"
  }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.benchmark_vpc.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.benchmark_vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "benchmark_subnet" {
  vpc_id                  = "${aws_vpc.benchmark_vpc.id}"
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "benchmark_security_group" {
  name        = "terraform"
  vpc_id      = "${aws_vpc.benchmark_vpc.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All ports open within the VPC
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
      Name = "Benchmark-Security-Group"
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

resource "aws_instance" "zookeeper" {
    ami           = "${var.ami}"
    instance_type = "t2.small"
    key_name      = "${aws_key_pair.auth.id}"
    subnet_id     = "${aws_subnet.benchmark_subnet.id}"
    vpc_security_group_ids = ["${aws_security_group.benchmark_security_group.id}"]
    count         = 3

    tags {
        Name = "zk-${count.index}"
    }
}

resource "aws_instance" "pulsar" {
    ami           = "${var.ami}"
    instance_type = "i3.4xlarge"
    key_name      = "${aws_key_pair.auth.id}"
    subnet_id     = "${aws_subnet.benchmark_subnet.id}"
    vpc_security_group_ids = ["${aws_security_group.benchmark_security_group.id}"]
    count         = 3

    tags {
        Name = "pulsar-${count.index}"
    }
}

resource "aws_instance" "client" {
    ami           = "${var.ami}"
    instance_type = "c4.8xlarge"
    key_name      = "${aws_key_pair.auth.id}"
    subnet_id     = "${aws_subnet.benchmark_subnet.id}"
    vpc_security_group_ids = ["${aws_security_group.benchmark_security_group.id}"]
    count         = 1

    tags {
        Name = "pulsar-client-${count.index}"
    }
}
