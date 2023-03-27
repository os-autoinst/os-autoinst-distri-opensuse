terraform {
  required_providers {
    azurerm = {
      version = ">= 3.2.0"
      source = "hashicorp/azurerm"
    }
    random = {
      version = "= 3.1.0"
      source = "hashicorp/random"
    }
  }
}

provider "azurerm" {
    features {}
}

## ---- variables ----------------------------------------------------------- ##

## general variables

variable "name" {
    default = "openqa-vm"
}

variable "tags" {
    type = map(string)
    default = {}
}

variable "region" {
    default = "westeurope"
}

## vm-instance variables

variable "instance_count" {
    default = "1"
}
variable "type" {
    default = "Standard_A2_v2"
}

variable "image_id" {
    default = ""
}

variable "offer" {
    default=""
}

variable "sku" {
    default="gen1"
}

variable "vm_create_timeout" {
    default = "20m"
}

## ---- data ---------------------------------------------------------------- ##

// IP address of the client
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

## -------------------------------------------------------------------------- ##

resource "random_id" "service" {
    keepers = {
        name = var.name
    }
    byte_length = 8
}

## resource group

resource "azurerm_resource_group" "openqa-group" {
    name     = "${var.name}-${element(random_id.service.*.hex, 0)}"
    location = var.region

    tags = merge({
            openqa_created_by = var.name
            openqa_created_date = timestamp()
            openqa_created_id = element(random_id.service.*.hex, 0)
        }, var.tags)
}

## virtual network

resource "azurerm_virtual_network" "openqa-network" {
    name                = "${azurerm_resource_group.openqa-group.name}-vnet"
    address_space       = ["192.168.0.0/16"]
    location            = var.region
    resource_group_name = azurerm_resource_group.openqa-group.name
}

resource "azurerm_subnet" "openqa-subnet" {
    name                 = "${azurerm_resource_group.openqa-group.name}-subnet"
    resource_group_name  = azurerm_resource_group.openqa-group.name
    virtual_network_name = azurerm_virtual_network.openqa-network.name
    address_prefixes     = ["192.168.1.0/24"]
    service_endpoints    = ["Microsoft.Storage"]
}

resource "azurerm_public_ip" "openqa-publicip" {
    name                         = "${azurerm_resource_group.openqa-group.name}-public-ip"
    location                     = var.region
    resource_group_name          = azurerm_resource_group.openqa-group.name
    allocation_method            = "Dynamic"
    count                        = var.instance_count
}

resource "azurerm_network_security_group" "openqa-nsg" {
    name                = "${azurerm_resource_group.openqa-group.name}-nsg"
    location            = var.region
    resource_group_name = azurerm_resource_group.openqa-group.name

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

resource "azurerm_subnet_network_security_group_association" "openqa-net-sec-association" {
    subnet_id                   = azurerm_subnet.openqa-subnet.id
    network_security_group_id   = azurerm_network_security_group.openqa-nsg.id
}

resource "azurerm_network_interface" "openqa-nic" {
    name                      = "${azurerm_resource_group.openqa-group.name}-nic"
    location                  = var.region
    resource_group_name       = azurerm_resource_group.openqa-group.name
    count                     = var.instance_count

    ip_configuration {
        name                          = "${element(random_id.service.*.hex, count.index)}-nic-config"
        subnet_id                     = azurerm_subnet.openqa-subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = element(azurerm_public_ip.openqa-publicip.*.id, count.index)
    }
}

## storage and NFS share

resource "azurerm_storage_account" "openqa-group" {
  name                      = "storage${element(random_id.service.*.hex, 0)}"
  resource_group_name       = azurerm_resource_group.openqa-group.name
  location                  = azurerm_resource_group.openqa-group.location
  account_tier              = "Premium"    # Required for NFS share
  account_replication_type  = "LRS"
  account_kind              = "FileStorage"
  enable_https_traffic_only = false
}

resource "azurerm_storage_account_network_rules" "openqa-group" {
  depends_on = [azurerm_storage_share.openqa-group]

  storage_account_id         = azurerm_storage_account.openqa-group.id
  default_action             = "Deny"
  virtual_network_subnet_ids = [azurerm_subnet.openqa-subnet.id]
  // AZURE LIMITATION: After setting Deny, we need to allow this host otherwise we cannot do changes or delete the resources
  ip_rules = [chomp(data.http.myip.response_body)]
  
  private_link_access {
    endpoint_resource_id     = azurerm_subnet.openqa-subnet.id
  }
}


resource "azurerm_storage_share" "openqa-group" {
  name                 = "nfsdata"
  storage_account_name = azurerm_storage_account.openqa-group.name
  quota                = 100
  enabled_protocol     = "NFS"
}

## virtual machine

resource "azurerm_image" "image" {
    name                      = "${azurerm_resource_group.openqa-group.name}-disk1"
    location                  = var.region
    resource_group_name       = azurerm_resource_group.openqa-group.name
    count = var.image_id != "" ? 1 : 0

    os_disk {
        os_type = "Linux"
        os_state = "Generalized"
        blob_uri = "https://openqa.blob.core.windows.net/sle-images/${var.image_id}"
        size_gb = 30
    }
}

resource "azurerm_linux_virtual_machine" "openqa-vm" {
  name                = "${var.name}-${element(random_id.service.*.hex, count.index)}"
  resource_group_name = azurerm_resource_group.openqa-group.name
  location            = var.region
  size                = var.type
  computer_name       = "${var.name}-${element(random_id.service.*.hex, count.index)}"
  admin_username      = "azureuser"
  disable_password_authentication = true

  count                 = var.instance_count

  network_interface_ids = [azurerm_network_interface.openqa-nic[count.index].id]

  tags = merge({
          openqa_created_by = var.name
          openqa_created_date = timestamp()
          openqa_created_id = element(random_id.service.*.hex, count.index)
      }, var.tags)

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    name                 = "${var.name}-${element(random_id.service.*.hex, count.index)}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    # SLE images are 30G by default. Uncomment this line in case we need to increase the disk size
    # note: value can not be decreased because 30 GB is minimum allowed by Azure
    # disk_size_gb         = 30
  }

  source_image_id =  var.image_id != "" ? azurerm_image.image.0.id : null
  dynamic "source_image_reference" {
    for_each = range(var.image_id != "" ? 0 : 1)
    content {
      publisher = var.image_id != "" ? "" : "SUSE"
      offer     = var.image_id != "" ? "" : var.offer
      sku       = var.image_id != "" ? "" : var.sku
      version   = var.image_id != "" ? "" : "latest"
    }
  }

  timeouts {
    create = var.vm_create_timeout
  }
}

output "vm_name" {
    value = azurerm_linux_virtual_machine.openqa-vm.*.id
}

data "azurerm_public_ip" "openqa-publicip" {
    name                = azurerm_public_ip.openqa-publicip[count.index].name
    resource_group_name = azurerm_linux_virtual_machine.openqa-vm.0.resource_group_name
    count               = var.instance_count
}

output "public_ip" {
    value = data.azurerm_public_ip.openqa-publicip.*.ip_address
}

output "resource_id" {
    value = "${element(random_id.service.*.hex, 0)}"
}
