provider "aws" {}

variable "count" {
    default = "1"
}

variable "name" {
    default = "openqa-vm"
}

variable "type" {
    default = "t2.large"
}

variable "image_id" {
    default = ""
}

resource "random_id" "service" {
    count = "${var.count}"
    keepers {
        name = "${var.name}"
    }
    byte_length = 8
}

resource "aws_key_pair" "openqa-keypair" {
    key_name   = "openqa-${random_id.service.hex}"
    public_key = "${file("/root/.ssh/id_rsa.pub")}"
}

resource "aws_security_group" "basic_sg" {
    name        = "openqa-${random_id.service.hex}"
    description = "Allow all inbound traffic"

    ingress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
    }
}

resource "aws_instance" "openqa" {
    count           = "${var.count}"
    ami             = "${var.image_id}"
    instance_type   = "${var.type}"
    key_name        = "${aws_key_pair.openqa-keypair.key_name}"
    security_groups = ["${aws_security_group.basic_sg.name}"]
}

output "public_ip" {
    value = "${aws_instance.openqa.*.public_ip}"
}

output "vm_name" {
    value = "${aws_instance.openqa.*.id}"
}
