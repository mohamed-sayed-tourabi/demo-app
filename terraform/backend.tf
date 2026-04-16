terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-francecentral-rg"
    storage_account_name = "tfstatefrancecentralww"
    container_name       = "tfstate"
    key                  = "global-azure-demo.terraform.tfstate"
  }
}
