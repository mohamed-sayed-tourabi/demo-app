variable "app_name" {
  description = "Name of the Container App"
  type        = string
}

variable "environment_name" {
  description = "Name of the Container Apps Environment"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy into"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics Workspace"
  type        = string
}

variable "identity_name" {
  description = "Name of the pre-existing User-Assigned Managed Identity with AcrPull on the ACR (created by admin)"
  type        = string
}

variable "identity_resource_group_name" {
  description = "Resource group where the pre-existing Managed Identity lives"
  type        = string
}

variable "acr_login_server" {
  description = "Login server FQDN of the ACR (e.g. myacr.azurecr.io)"
  type        = string
}

variable "image_name" {
  description = "Docker image name stored in ACR"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
}

variable "tags" {
  description = "Tags applied to all container-app resources"
  type        = map(string)
  default     = {}
}
