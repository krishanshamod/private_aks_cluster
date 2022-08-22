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