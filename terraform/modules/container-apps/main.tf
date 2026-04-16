# Look up the pre-existing User-Assigned Managed Identity created by the admin.
# The admin is responsible for creating this identity and granting it AcrPull on the ACR.
data "azurerm_user_assigned_identity" "acr_rbac" {
  name                = var.identity_name
  resource_group_name = var.identity_resource_group_name
}

resource "azurerm_container_app_environment" "this" {
  name                       = var.environment_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  log_analytics_workspace_id = var.log_analytics_workspace_id
  tags                       = var.tags
}

resource "azurerm_container_app" "this" {
  name                         = var.app_name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.this.id
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.acr_rbac.id]
  }

  # Pull from ACR using Managed Identity — no passwords stored in Terraform
  registry {
    server   = var.acr_login_server
    identity = data.azurerm_user_assigned_identity.acr_rbac.id
  }

  template {
    min_replicas = 0
    max_replicas = 3

    container {
      name   = var.app_name
      image  = "${var.acr_login_server}/${var.image_name}:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "AZURE_REGION"
        value = var.location
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 3000

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

}
