variable "workspace_name" {
  description = "Name of the Log Analytics Workspace"
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

variable "tags" {
  description = "Tags applied to the workspace resource"
  type        = map(string)
  default     = {}
}
