terraform {
  required_providers {
    aws = {
      version = "= 5.14.0"
      source = "hashicorp/aws"
    }
    random = {
      version = "= 3.1.0"
      source = "hashicorp/random"
    }
  }
}

variable "region" {
    default = "eu-central-1"
}

provider "aws" {
    region = var.region
}

variable "instance_count" {
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

variable "extra-disk-size" {
    default = "1000"
}

variable "extra-disk-type" {
    default = "gp2"
}

variable "create-extra-disk" {
    default=false
}

variable "tags" {
    type = map(string)
    default = {}
}

variable "vm_create_timeout" {
    default = "20m"
}

variable "enable_confidential_vm" {
    default = "disabled"
}

variable "vpc_security_group_ids" {
    default = ""
}

variable "subnet_id" {
    default = ""
}

variable "ipv6_address_count" {
    default = 0
}

resource "random_id" "service" {
    count = var.instance_count
    keepers = {
        name = var.name
    }
    byte_length = 8
}

resource "aws_key_pair" "openqa-keypair" {
    key_name   = "openqa-${element(random_id.service.*.hex, 0)}"
    public_key = file("/root/.ssh/id_rsa.pub")
}

resource "aws_instance" "openqa" {
    count           = var.instance_count
    ami             = var.image_id
    instance_type   = var.type
    key_name        = aws_key_pair.openqa-keypair.key_name
    vpc_security_group_ids = [var.vpc_security_group_ids]
    subnet_id = var.subnet_id
    ipv6_address_count = var.ipv6_address_count

    tags = merge({
            openqa_created_by = var.name
            openqa_created_date = timestamp()
            openqa_created_id = element(random_id.service.*.hex, count.index)
        }, var.tags)

    ebs_block_device {
        device_name = "/dev/sda1"
        volume_size = 20
    }

    timeouts {
        create = var.vm_create_timeout
    }

    dynamic "cpu_options" {
        for_each = var.enable_confidential_vm == "disabled" ? [] : [1]
        content {
            amd_sev_snp = var.enable_confidential_vm
        }
    }
}

resource "aws_volume_attachment" "ebs_att" {
    count       =  var.create-extra-disk ? var.instance_count: 0
    device_name = "/dev/sdb"
    volume_id   = element(aws_ebs_volume.ssd_disk.*.id, count.index)
    instance_id = element(aws_instance.openqa.*.id, count.index)
}

resource "aws_ebs_volume" "ssd_disk" {
    count             = var.create-extra-disk ? var.instance_count : 0
    availability_zone = element(aws_instance.openqa.*.availability_zone, count.index)
    size              = var.extra-disk-size
    type              = var.extra-disk-type
    tags = merge({
            openqa_created_by = var.name
            openqa_created_date = timestamp()
            openqa_created_id = element(random_id.service.*.hex, count.index)
        }, var.tags)
}

output "public_ip" {
    value = aws_instance.openqa.*.public_ip
}

output "vm_name" {
    value = aws_instance.openqa.*.id
}
