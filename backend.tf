terraform {
    backend "azurerm" {
        resource_group_name  = "terraform-state"
        storage_account_name = "aksclustertfstate1999"
        container_name       = "tfstate"
        key                  = "terraform.tfstate"
    }
}