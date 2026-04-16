variable "acr_name" {
  description = "Globally unique name for the Container Registry"
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
  description = "Tags applied to the ACR resource"
  type        = map(string)
  default     = {}
}
