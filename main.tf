provider "azurerm" {
  version = "~> 1.27"
  subscription_id = "${var.SUBID}"
  client_id = "${var.CLIENTID}"
  client_certificate_path ="${var.CERTPATH}"
  client_certificate_password = "${var.CERTPASS}"
  tenant_id = "${var.TENANTID}"
}


resource "azurerm_resource_group" "webappsamplegroup" {
    name     = "webappsamplegroup"
    location = "eastus"

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_resource_group" "linuxtraininggroup" {
    name     = "Linux_Training_RG"
    location = "eastus"
}


# Create virtual network
resource "azurerm_virtual_network" "webappsamplevnet" {
    name                = "webappsamplevnet"
    address_space       = ["192.168.1.0/24"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.webappsamplegroup.name

    tags = {
        environment = "Terraform Demo"
    }
}

# Create subnet
resource "azurerm_subnet" "webappsamplesubnet_2" {
    name                 = "webappsamplesubnet_2"
    resource_group_name  = azurerm_resource_group.webappsamplegroup.name
    virtual_network_name = azurerm_virtual_network.webappsamplevnet.name
    address_prefix       = "192.168.1.0/25"
}


resource "azurerm_virtual_network" "linux_vnet" {
    name = "Linux_Training_RG-vnet"
    resource_group_name = azurerm_resource_group.linuxtraininggroup.name
    address_space       = ["10.0.0.0/24"]
    location            = "eastus"
}


# Create subnet
resource "azurerm_subnet" "linux_default_subnet" {
    name                 = "default"
    resource_group_name  = azurerm_resource_group.linuxtraininggroup.name
    virtual_network_name = azurerm_virtual_network.linux_vnet.name
    address_prefix       = "10.0.0.0/24"
}

#Create vnet peerings
resource "azurerm_virtual_network_peering" "webbapp_to_linux_peering" {
    name                      = "WebAppToLinux"
    resource_group_name       = azurerm_resource_group.webappsamplegroup.name
    virtual_network_name      = azurerm_virtual_network.webappsamplevnet.name
    remote_virtual_network_id = azurerm_virtual_network.linux_vnet.id
}

resource "azurerm_virtual_network_peering" "linux_to_webapp_peering" {
    name                      = "LinuxtoWebApp"
    resource_group_name       = "Linux_Training_RG"
    virtual_network_name      = azurerm_virtual_network.linux_vnet.name
    remote_virtual_network_id = azurerm_virtual_network.webappsamplevnet.id
}
     

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.webappsamplegroup.name
    }

    byte_length = 8
}


# Create Network Security Group and rule
resource "azurerm_network_security_group" "webappnsg" {
    name                = "mysqlnsg${random_id.randomId.hex}"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.webappsamplegroup.name

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

    security_rule {
        name                       = "MySQL"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3306"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }


    tags = {
        environment = "Terraform Demo"
    }
}

#Generate random string for hostname
resource "random_string" "random" {
  length = 16
  special = false
}

# Create network interface
resource "azurerm_network_interface" "mysqlnic" {
    name                      = "mysqlnic_${random_id.randomId.hex}"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.webappsamplegroup.name
    network_security_group_id = azurerm_network_security_group.webappnsg.id

    ip_configuration {
        name                          = "nicconfig_diag${random_id.randomId.hex}"
        subnet_id                     = azurerm_subnet.webappsamplesubnet_2.id
        private_ip_address_allocation = "Dynamic"
     }
}


# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mysqldiagaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.webappsamplegroup.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_recovery_services_vault" "webappbackupvault" {
  name                = "WebAppBackupVault"
  location            = "EastUS"
  resource_group_name = "${azurerm_resource_group.webappsamplegroup.name}"
  sku                 = "Standard"
}


resource "azurerm_backup_policy_vm" "default_policy" {
  name                = "webappvaultpolicy"
  resource_group_name = "${azurerm_resource_group.webappsamplegroup.name}"
  recovery_vault_name = "WebAppBackupVault"

  backup {
    frequency = "Daily"
    time      = "23:00"
  }
  retention_daily {
    count = 7
  }
}




# Create virtual machine
resource "azurerm_virtual_machine" "mysqlubuntuvm" {
    name                  = "MySQL${random_string.random.result}"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.webappsamplegroup.name
    network_interface_ids = [azurerm_network_interface.mysqlnic.id]
    vm_size               = "Standard_B1s"

    storage_image_reference {
        publisher = "Canonical"
        offer = "UbuntuServer"
        sku = "18.04-LTS"
        version = "latest"
    }
    storage_os_disk {
        name              = "mysqlosdisk${random_string.random.result}"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    os_profile {
        computer_name  =  "mysql${random_string.random.result}"
        admin_username = "azureuser"
        admin_password = "Fattycakes1"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }



    boot_diagnostics {
        enabled = "true"
        storage_uri = azurerm_storage_account.mysqldiagaccount.primary_blob_endpoint
    }
}
resource "azurerm_backup_protected_vm" "vm_to_protect" {
  resource_group_name = "${azurerm_resource_group.webappsamplegroup.name}"
  recovery_vault_name = "${azurerm_recovery_services_vault.webappbackupvault.name}"
  source_vm_id        = "${azurerm_virtual_machine.mysqlubuntuvm.id}"
  backup_policy_id    = "${azurerm_backup_policy_vm.default_policy.id}"
 }


