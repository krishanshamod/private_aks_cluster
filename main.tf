provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "my_rg" {
  name     = "rg-private-aks"
  location = var.location.value
}

resource "azurerm_virtual_network" "vnet_cluster" {
  name                = "vnet-private-aks-demo"
  location            = var.location.value
  resource_group_name = azurerm_resource_group.my_rg.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "snet_cluster" {
  name                 = "snet-private-aks-demo"
  resource_group_name  = azurerm_resource_group.my_rg.name
  virtual_network_name = azurerm_virtual_network.vnet_cluster.name
  address_prefixes     = ["10.1.0.0/24"]
  

  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_virtual_network" "vnet_bastion" {
  name                = "vnet-bastion-demo"
  location            = var.location.value
  resource_group_name = azurerm_resource_group.my_rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "snet_bastion_vm" {
  name                 = "snet-bastion-demo"
  resource_group_name  = azurerm_resource_group.my_rg.name
  virtual_network_name = azurerm_virtual_network.vnet_bastion.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "snet_azure_bastion_service" {

  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.my_rg.name
  virtual_network_name = azurerm_virtual_network.vnet_bastion.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_virtual_network_peering" "peering_bastion_cluster" {
  name                      = "peering_bastion_cluster"
  resource_group_name       = azurerm_resource_group.my_rg.name
  virtual_network_name      = azurerm_virtual_network.vnet_bastion.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_cluster.id
}

resource "azurerm_virtual_network_peering" "peering_cluster_bastion" {
  name                      = "peering_cluster_bastion"
  resource_group_name       = azurerm_resource_group.my_rg.name
  virtual_network_name      = azurerm_virtual_network.vnet_cluster.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_bastion.id
}

resource "azurerm_kubernetes_cluster" "my_aks" {
  name                = "aks-my-cluster"
  location            = var.location.value
  resource_group_name = azurerm_resource_group.my_rg.name
  dns_prefix          = "aks-cluster"
 
  private_cluster_enabled = true

  network_profile {
    network_plugin     = "kubenet"
    docker_bridge_cidr = "192.167.0.1/16"
    dns_service_ip     = "192.168.1.1"
    service_cidr       = "192.168.0.0/16"
    pod_cidr           = "172.16.0.0/22"
  }

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.snet_cluster.id
  }

  service_principal {
    client_id     = var.aks_service_principal_client_id
    client_secret = var.aks_service_principal_client_secret
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_bastion_cluster" {
  name = "dnslink-bastion-cluster"
  private_dns_zone_name = join(".", slice(split(".", azurerm_kubernetes_cluster.my_aks.private_fqdn), 1, length(split(".", azurerm_kubernetes_cluster.my_aks.private_fqdn))))
  resource_group_name   = "MC_${azurerm_resource_group.my_rg.name}_${azurerm_kubernetes_cluster.my_aks.name}_${var.location.suffix}"
  virtual_network_id    = azurerm_virtual_network.vnet_bastion.id
}

resource "azurerm_network_interface" "bastion_nic" {
  name                = "nic-bastion"
  location            = var.location.value
  resource_group_name = azurerm_resource_group.my_rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_bastion_vm.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "example" {
  name                            = "vm-bastion"
  location                        = var.location.value
  resource_group_name             = azurerm_resource_group.my_rg.name
  size                            = "Standard_D2_v2"
  admin_username                  = var.bastion_admin_username
  admin_password                  = var.bastion_admin_password
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.bastion_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_public_ip" "pip_azure_bastion" {
  name                = "pip-azure-bastion"
  location            = var.location.value
  resource_group_name = azurerm_resource_group.my_rg.name

  allocation_method = "Static"
  sku               = "Standard"
}

resource "azurerm_bastion_host" "azure-bastion" {
  name                = "azure-bastion"
  location            = var.location.value
  resource_group_name = azurerm_resource_group.my_rg.name
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.snet_azure_bastion_service.id
    public_ip_address_id = azurerm_public_ip.pip_azure_bastion.id
  }
}