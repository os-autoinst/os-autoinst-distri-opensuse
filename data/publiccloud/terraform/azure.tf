provider "azurerm" {}

variable "count" {
    default = "1"
}

variable "name" {
    default = "openqa-vm"
}

variable "type" {
    default = "Standard_A2_v2"
}

variable "region" {
    default = "westeurope"
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


resource "azurerm_resource_group" "openqa-group" {
    name     = "openqa-${random_id.service.hex}"
    location = "${var.region}"

    tags = {
        openqa_created_by = "${var.name}"
        openqa_created_date = "${timestamp()}"
        openqa_created_id = "${random_id.service.hex}"
    }
}

resource "azurerm_virtual_network" "openqa-network" {
    name                = "${azurerm_resource_group.openqa-group.name}-vnet"
    address_space       = ["10.0.0.0/16"]
    location            = "${var.region}"
    resource_group_name = "${azurerm_resource_group.openqa-group.name}"
}

resource "azurerm_subnet" "openqa-subnet" {
    name                 = "${azurerm_resource_group.openqa-group.name}-subnet"
    resource_group_name  = "${azurerm_resource_group.openqa-group.name}"
    virtual_network_name = "${azurerm_virtual_network.openqa-network.name}"
    address_prefix       = "10.0.1.0/24"
}

resource "azurerm_public_ip" "openqa-publicip" {
    name                         = "${azurerm_resource_group.openqa-group.name}-public-ip"
    location                     = "${var.region}"
    resource_group_name          = "${azurerm_resource_group.openqa-group.name}"
    public_ip_address_allocation = "dynamic"
}

resource "azurerm_network_security_group" "openqa-nsg" {
    name                = "${azurerm_resource_group.openqa-group.name}-nsg"
    location            = "${var.region}"
    resource_group_name = "${azurerm_resource_group.openqa-group.name}"

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_network_interface" "openqa-nic" {
    name                      = "${azurerm_resource_group.openqa-group.name}-nic"
    location                  = "${var.region}"
    resource_group_name       = "${azurerm_resource_group.openqa-group.name}"
    network_security_group_id = "${azurerm_network_security_group.openqa-nsg.id}"

    ip_configuration {
        name                          = "openqa-nic-config"
        subnet_id                     = "${azurerm_subnet.openqa-subnet.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${azurerm_public_ip.openqa-publicip.id}"
    }
}

resource "azurerm_image" "image" {
    name                      = "${azurerm_resource_group.openqa-group.name}-disk1"
    location                  = "${var.region}"
    resource_group_name       = "${azurerm_resource_group.openqa-group.name}"

    os_disk {
        os_type = "Linux"
        os_state = "Generalized"
        blob_uri = "https://openqa.blob.core.windows.net/sle-images/${var.image_id}"
        size_gb = 30
    }
}

resource "azurerm_virtual_machine" "openqa-vm" {
    name                  = "${azurerm_resource_group.openqa-group.name}"
    location              = "${var.region}"
    resource_group_name   = "${azurerm_resource_group.openqa-group.name}"
    network_interface_ids = ["${azurerm_network_interface.openqa-nic.id}"]
    vm_size               = "${var.type}"

    storage_image_reference {
        id = "${azurerm_image.image.id}"
    }

    storage_os_disk {
        name          = "${var.name}-${element(random_id.service.*.hex, count.index)}-osdisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    os_profile {
        computer_name  = "${var.name}-${element(random_id.service.*.hex, count.index)}"
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "${file("/root/.ssh/id_rsa.pub")}"
        }
    }

    tags = {
        openqa_created_by = "${var.name}"
        openqa_created_date = "${timestamp()}"
        openqa_created_id = "${element(random_id.service.*.hex, count.index)}"
    }
}

output "vm_name" {
    value = "${azurerm_virtual_machine.openqa-vm.*.name}"
}

data "azurerm_public_ip" "openqa-publicip" {
    name                = "${azurerm_public_ip.openqa-publicip.name}"
    resource_group_name = "${azurerm_virtual_machine.openqa-vm.resource_group_name}"
}

output "public_ip" {
    value = "${data.azurerm_public_ip.openqa-publicip.*.ip_address}"
}
