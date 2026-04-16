terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

# ── Resource Group ──────────────────────────────────────────────────────────
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ── ACR ─────────────────────────────────────────────────────────────────────
module "acr" {
  source = "./modules/acr"

  acr_name            = var.acr_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags
}

# ── Log Analytics ────────────────────────────────────────────────────────────
module "log_analytics" {
  source = "./modules/log-analytics"

  workspace_name      = var.log_analytics_workspace_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags
}

# ── Container Apps ───────────────────────────────────────────────────────────
module "container_apps" {
  source = "./modules/container-apps"

  app_name                     = var.app_name
  environment_name             = var.environment_name
  resource_group_name          = azurerm_resource_group.this.name
  location                     = azurerm_resource_group.this.location
  log_analytics_workspace_id   = module.log_analytics.workspace_resource_id
  acr_login_server             = module.acr.login_server
  identity_name                = var.identity_name
  identity_resource_group_name = var.identity_resource_group_name
  image_name                   = var.image_name
  image_tag                    = var.image_tag
  tags                         = var.tags
}
