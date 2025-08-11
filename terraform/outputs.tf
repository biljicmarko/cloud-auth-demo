output "azure_public_ip" {
  description = "Public IPv4 of the VM"
  value       = module.network.public_ip_address
}

output "azure_public_fqdn" {
  description = "Public FQDN of the public IP"
  value       = module.network.public_fqdn
}
