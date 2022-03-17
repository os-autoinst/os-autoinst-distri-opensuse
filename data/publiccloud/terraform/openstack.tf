terraform {
  required_providers {
    openstack = {
      version = ">= 0.14.0"
      source  = "terraform-provider-openstack/openstack"
    }
    random = {
      version = "= 3.1.0"
      source  = "hashicorp/random"
    }
    external = {
      version = "= 2.1.0"
      source  = "hashicorp/external"
    }
  }
}

provider "openstack" {
  cloud = "mycloud"
}

variable "name" {
  default = "openqa-vm"
}

variable "keypair" {
  description = "Public Key to be injected to the instance"
  type        = string
  default     = ""
}

variable "image_id" {
  description = "Image ID to boot the instance"
  type        = string
  default     = ""
}

variable "secgroup" {
  description = "Security group to be used"
  type        = string
  default     = "icmp_ssh"
}

variable "type" {
  description = "Flavor (cpu, ram) to boot the instance"
  type        = string
  default     = "m1.small"
}

variable "instance_count" {
  default = "1"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "region" {
  default = "CustomRegion"
}


resource "random_id" "service" {
  count = var.instance_count
  keepers = {
    name = var.name
  }
  byte_length = 8
}

data "template_file" "cloudinit_jeos" {
  template = file("/root/mn_jeos.cloud-init")
}

resource "openstack_compute_instance_v2" "openqa_instance" {
  count           = var.instance_count
  name            = "${var.name}-${element(random_id.service.*.hex, count.index)}"
  image_id        = var.image_id
  flavor_name     = var.type
  key_pair        = var.keypair
  security_groups = [var.secgroup]
  region          = var.region
  user_data       = data.template_file.cloudinit_jeos.rendered
  network {
    name = "fixed"
  }
}

resource "openstack_networking_floatingip_v2" "floating_ip" {
  count = var.instance_count
  pool  = "floating"
}

resource "openstack_compute_floatingip_associate_v2" "floating_ip" {
  count       = var.instance_count
  floating_ip = openstack_networking_floatingip_v2.floating_ip[count.index].address
  instance_id = openstack_compute_instance_v2.openqa_instance[count.index].id
}

output "vm_name" {
  value = openstack_compute_instance_v2.openqa_instance.*.name
}

output "public_ip" {
  value = openstack_networking_floatingip_v2.floating_ip.*.address
}
