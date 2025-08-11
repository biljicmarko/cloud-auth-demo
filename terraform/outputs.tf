output "azure_public_ip" {
  value = module.network.public_ip
}

output "azure_public_fqdn" {
  value = module.network.public_fqdn
}
