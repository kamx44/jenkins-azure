terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.18.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

variable "prefix" {
  default = "jenkins"
}

resource "azurerm_resource_group" "jenkins_rg" {
  name     = "${var.prefix}-resources"
  location = "East US"
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.jenkins_rg.location
  resource_group_name = azurerm_resource_group.jenkins_rg.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.jenkins_rg.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "jenkins_sg" {
  name                = "jenkins-sg"
  location            = azurerm_resource_group.jenkins_rg.location
  resource_group_name = azurerm_resource_group.jenkins_rg.name

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_security_rule" "outbound" {
  name                        = "outbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.jenkins_rg.name
  network_security_group_name = azurerm_network_security_group.jenkins_sg.name
}

resource "azurerm_network_security_rule" "ssh_access" {
  name                        = "ssh_access"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "85.31.253.3/32"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.jenkins_rg.name
  network_security_group_name = azurerm_network_security_group.jenkins_sg.name
}

resource "azurerm_network_security_rule" "http_access" {
  name                        = "https_access"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.jenkins_rg.name
  network_security_group_name = azurerm_network_security_group.jenkins_sg.name
}

resource "azurerm_public_ip" "jenkins_pub_ip" {
  name                = "jenkins-pub-ip"
  location            = azurerm_resource_group.jenkins_rg.location
  resource_group_name = azurerm_resource_group.jenkins_rg.name
  allocation_method   = "Dynamic"
  domain_name_label   = "kamiljenkins"

  tags = {
    environment = "Dev"
  }
}

resource "azurerm_network_interface" "jenkins_ni" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.jenkins_rg.location
  resource_group_name = azurerm_resource_group.jenkins_rg.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jenkins_pub_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "association" {
  network_interface_id      = azurerm_network_interface.jenkins_ni.id
  network_security_group_id = azurerm_network_security_group.jenkins_sg.id
}


resource "azurerm_virtual_machine" "main" {
  name                  = "${var.prefix}-vm"
  location              = azurerm_resource_group.jenkins_rg.location
  resource_group_name   = azurerm_resource_group.jenkins_rg.name
  network_interface_ids = [azurerm_network_interface.jenkins_ni.id]
  vm_size               = "Standard_B1s"

  
  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7_9-gen2"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb      = 30
  }
  os_profile {
    computer_name  = "jenkins"
    admin_username = "kamil"
    custom_data = filebase64("scripts/jenkins-install.sh")
  }
  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = file("~/.ssh/az_rsa.pub")
      path = "/home/kamil/.ssh/authorized_keys"
    }
  }
  tags = {
    environment = "dev"
  }
}

output "public_ip" {
  value = azurerm_public_ip.jenkins_pub_ip.ip_address
}