variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "acr_name" {
  description = "Globally unique name for the Azure Container Registry"
  type        = string
}

variable "app_name" {
  description = "Name of the Container App"
  type        = string
}

variable "image_name" {
  description = "Docker image name (without tag) stored in ACR"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "environment_name" {
  description = "Name of the Container Apps Environment"
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  type        = string
}

variable "identity_name" {
  description = "Name of the pre-existing User-Assigned Managed Identity (admin-created, has AcrPull on ACR)"
  type        = string
}

variable "identity_resource_group_name" {
  description = "Resource group where the pre-existing Managed Identity lives"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources (cost-center, environment, owner, project)"
  type        = map(string)
  default     = {}
}
