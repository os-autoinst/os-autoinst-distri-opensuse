variable "remote_ip" {}

variable "count" {
    default = "2"
}

provider "libvirt" {
     uri = "qemu+ssh://root@${var.remote_ip}/system"
}

variable "hdd" {
}

resource "random_id" "service" {
    count = "${var.count}"
    byte_length = 4
}

resource "libvirt_volume" "myvdisk" {
  name = "terraform-vdisk-${element(random_id.service.*.hex, count.index)}.qcow2"
  count = "${var.count}"
  pool = "default"
  source = "${var.hdd}"
  format = "qcow2"
}

resource "libvirt_network" "my_net" {
   name = "terraform-net-${element(random_id.service.*.hex, count.index)}"
   addresses = ["10.0.1.0/24"]
   dhcp {
		enabled = true
	}
}

resource "libvirt_domain" "domain-sle" {
  name = "terraform-vm-${element(random_id.service.*.hex, count.index)}"
  memory = "4096"
  vcpu = 4
  count = "${var.count}"

  network_interface {
    network_id = "${libvirt_network.my_net.id}"
    wait_for_lease = true
  }

  disk {
   volume_id = "${libvirt_volume.myvdisk.*.id[count.index]}"
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
      type        = "pty"
      target_type = "virtio"
      target_port = "1"
  }

  graphics {
    type = "vnc"
    listen_type = "address"
    autoport = "true"
  }
}

output "vm_ips" {
    value = "${libvirt_domain.domain-sle.*.network_interface.0.addresses}"
}

output "vm_names" {
    value = "${libvirt_domain.domain-sle.*.name}"
}
