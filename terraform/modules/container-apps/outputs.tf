output "fqdn" {
  description = "Public FQDN of the Container App"
  value       = azurerm_container_app.this.ingress[0].fqdn
}

output "identity_principal_id" {
  description = "Principal ID of the User-Assigned Managed Identity used for ACR pull"
  value       = data.azurerm_user_assigned_identity.acr_rbac.principal_id
}
