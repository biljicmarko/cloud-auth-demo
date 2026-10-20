variable "name" {
  description = "Name suffix for all network resources."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs allowed to reach SSH (empty = no SSH rule)."
  type        = list(string)
  default     = []
}
