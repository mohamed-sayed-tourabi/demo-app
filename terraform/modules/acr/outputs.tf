output "id" {
  description = "Resource ID of the Container Registry"
  value       = azurerm_container_registry.this.id
}

output "login_server" {
  description = "Login server FQDN of the Container Registry"
  value       = azurerm_container_registry.this.login_server
}
