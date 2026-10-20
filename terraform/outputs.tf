output "azure_public_ip" {
  value = module.network.public_ip
}

output "azure_public_fqdn" {
  value = module.network.public_fqdn
}

output "resource_group_name" {
  value = module.network.resource_group_name
}

output "nsg_name" {
  description = "Used by the deploy workflow to open SSH for the runner temporarily."
  value       = module.network.nsg_name
}
