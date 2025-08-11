output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "subnet_id" {
  value = azurerm_subnet.main.id
}

output "public_ip_id" {
  value = azurerm_public_ip.main.id
}

output "public_ip" {
  value = azurerm_public_ip.main.ip_address
}

output "public_fqdn" {
  value = azurerm_public_ip.main.fqdn
}

output "location" {
  value = azurerm_resource_group.main.location
}
