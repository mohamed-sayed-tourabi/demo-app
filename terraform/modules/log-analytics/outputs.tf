output "workspace_resource_id" {
  description = "Resource ID of the Log Analytics Workspace (used by Container Apps Environment)"
  value       = azurerm_log_analytics_workspace.this.id
}

output "workspace_customer_id" {
  description = "Customer/workspace GUID"
  value       = azurerm_log_analytics_workspace.this.workspace_id
}
