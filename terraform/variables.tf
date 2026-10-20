variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "westeurope"
}

variable "vm_size" {
  description = "VM size. Keycloak + Postgres need ~2 GiB RAM; B2ls_v2 has 4 GiB (B1s with 1 GiB is too small)."
  type        = string
  default     = "Standard_B2ls_v2"
}

variable "admin_username" {
  description = "Admin user on the VM (also used by Ansible)."
  type        = string
  default     = "azureuser"
}

variable "public_key" {
  description = "SSH public key (RSA) for the admin user."
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs allowed to reach SSH permanently. Empty = no permanent SSH rule; the deploy workflow opens SSH for its runner IP only while Ansible runs."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.allowed_ssh_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry in allowed_ssh_cidrs must be a valid CIDR, e.g. 203.0.113.10/32."
  }
}
