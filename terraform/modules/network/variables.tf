variable "name" {
  description = "Network name"
  type        = string
  default     = "default"
}

variable "location" {
  description = "Azure location"
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "RG name"
  type        = string
  default     = "test-rg"
}

