output "resource_group_name" {
  description = "Name of the provisioned resource group"
  value       = azurerm_resource_group.this.name
}

output "acr_login_server" {
  description = "Login server URL for the Azure Container Registry"
  value       = module.acr.login_server
}

output "container_app_fqdn" {
  description = "Fully-qualified domain name (FQDN) of the Container App"
  value       = module.container_apps.fqdn
}
