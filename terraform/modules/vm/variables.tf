variable "name" {
  description = "Name suffix for the VM and its NIC."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to create the VM in."
  type        = string
}

variable "subnet_id" {
  description = "Subnet for the VM's NIC."
  type        = string
}

variable "public_ip_id" {
  description = "Public IP attached to the NIC."
  type        = string
}

variable "size" {
  description = "VM size."
  type        = string
}

variable "admin_username" {
  description = "Admin user (SSH key auth only)."
  type        = string
}

variable "public_key" {
  description = "SSH public key for the admin user."
  type        = string
}
