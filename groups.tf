resource "azurerm_resource_group" "my_rg" {
  name     = "rg-private-aks"
  location = var.location.value
}