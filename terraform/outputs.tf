output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "subnet_app_id" {
  description = "Id de snet-app"
  value       = azurerm_subnet.app.id
}

output "subnet_data_id" {
  description = "Id de snet-data"
  value       = azurerm_subnet.data.id
}

output "subnet_jumpbox_id" {
  description = "Id de snet-jumpbox"
  value       = azurerm_subnet.jumpbox.id
}

output "natgw_public_ip" {
  description = "IP publique de sortie de snet-app"
  value       = azurerm_public_ip.natgw.ip_address
}
