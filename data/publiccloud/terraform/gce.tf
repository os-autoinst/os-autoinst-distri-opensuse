terraform {
  required_providers {
    google = {
      version = "= 4.57.0"
      source = "hashicorp/google"
    }
    random = {
      version = "= 3.1.0"
      source = "hashicorp/random"
    }
    external = {
      version = "= 2.1.0"
      source = "hashicorp/external"
    }
  }
}

variable "cred_file" {
    default = "/root/google_credentials.json"
}

provider "google" {
    credentials = var.cred_file
    project     = var.project
}

data "external" "gce_cred" {
    program = [ "cat", var.cred_file ]
    query =  { }
}

variable "instance_count" {
    default = "1"
}

variable "name" {
    default = "openqa-vm"
}

variable "type" {
    default = "n1-standard-2"
}

variable "region" {
    default = "europe-west1-b"
}

variable "image_id" {
    default = ""
}

variable "project" {
    default = "suse-sle-qa"
}

variable "extra-disk-size" {
    default = "1000"
}

variable "extra-disk-type" {
    default = "pd-ssd"
}

variable "create-extra-disk" {
    default=false
}

variable "uefi" {
    default=false
}

variable "tags" {
    type = map(string)
    default = {}
}

variable "enable_confidential_vm" {
	default=false
}

variable "gpu" {
  description = "Enable and configure node GPUs"

  default = false
}

variable "vm_create_timeout" {
    default = "20m"
}

resource "random_id" "service" {
    count = var.instance_count
    keepers = {
        name = var.name
    }
    byte_length = 8
}

resource "google_compute_instance" "openqa" {
    count                        = var.instance_count
    name                         = "${var.name}-${element(random_id.service.*.hex, count.index)}"
    machine_type                 = var.type
    zone                         = var.region

    guest_accelerator {
      type = "nvidia-tesla-t4"
      count = var.gpu ? 1 : 0
    }

    confidential_instance_config {
    	enable_confidential_compute = var.enable_confidential_vm ? true : false
    }

    boot_disk {
        device_name = "${var.name}-${element(random_id.service.*.hex, count.index)}"
        initialize_params {
            image = var.image_id
            size  = 20
        }
    }
    
    scheduling {
    	on_host_maintenance = "TERMINATE"
    }

    metadata = merge({
            sshKeys = "susetest:${file("/root/.ssh/id_rsa.pub")}"
            openqa_created_by = var.name
            openqa_created_date = timestamp()
            openqa_created_id = element(random_id.service.*.hex, count.index)
        }, var.tags)

    network_interface {
        network = "default"
            access_config {
        }
    }

    service_account {
        email = data.external.gce_cred.result["client_email"]
        scopes = ["cloud-platform"]
    }

    dynamic "shielded_instance_config" {
        for_each = var.uefi ? [ "UEFI" ] : []
        content {
            enable_secure_boot = "true"
            enable_vtpm = "true"
            enable_integrity_monitoring = "true"
        }
    }

    timeouts {
        create = var.vm_create_timeout
    }
}

resource "google_compute_attached_disk" "default" {
    count    =  var.create-extra-disk ? var.instance_count: 0
    disk     = element(google_compute_disk.default.*.self_link, count.index)
    instance = element(google_compute_instance.openqa.*.self_link, count.index)
}

resource "google_compute_disk" "default" {
    name                      = "ssd-disk-${element(random_id.service.*.hex, count.index)}"
    count                     = var.create-extra-disk ? var.instance_count : 0
    type                      = var.extra-disk-type
    zone                      = var.region
    size                      = var.extra-disk-size
    physical_block_size_bytes = 4096
    labels = {
        openqa_created_by = var.name
        openqa_created_id = element(random_id.service.*.hex, count.index)
    }
}

output "public_ip" {
    value = google_compute_instance.openqa.*.network_interface.0.access_config.0.nat_ip
}

output "vm_name" {
    value = google_compute_instance.openqa.*.name
}

output "confidential_instance_config" {
  value   = google_compute_instance.openqa.*.confidential_instance_config
}
