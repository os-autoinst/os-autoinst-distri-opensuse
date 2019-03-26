provider "google" {
    credentials = "/root/google_credentials.json"
    project     = "${var.project}"
}

variable "count" {
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

resource "random_id" "service" {
    count = "${var.count}"
    keepers {
        name = "${var.name}"
    }
    byte_length = 8
}

resource "google_compute_instance" "openqa" {
    count        = "${var.count}"
    name         = "${var.name}-${element(random_id.service.*.hex, count.index)}"
    machine_type = "${var.type}"
    zone         = "${var.region}"

    boot_disk {
        initialize_params {
            image = "${var.image_id}"
        }
    }

    metadata {
        sshKeys = "susetest:${file("/root/.ssh/id_rsa.pub")}"
        openqa_created_by = "${var.name}"
        openqa_created_date = "${timestamp()}"
        openqa_created_id = "${element(random_id.service.*.hex, count.index)}"
    }

    network_interface {
        network = "default"
            access_config {
        }
    }

}

output "public_ip" {
    value = "${google_compute_instance.openqa.*.network_interface.0.access_config.0.nat_ip}"
}

output "vm_name" {
    value = "${google_compute_instance.openqa.*.name}"
}
