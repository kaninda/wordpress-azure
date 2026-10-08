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

output "jumpbox_public_ip" {
  description = "IP publique de la jumpbox"
  value       = azurerm_public_ip.jumpbox.ip_address
}

output "app_private_ip" {
  description = "IP privee de la VM app"
  value       = azurerm_network_interface.app.private_ip_address
}

output "lb_public_ip" {
  description = "IP publique du LB"
  value       = azurerm_public_ip.lb.ip_address
}

# Lus par Ansible pour construire le chemin SMB //<compte>.file.core.windows.net/<partage>
output "storage_account_name" {
  value = azurerm_storage_account.media.name
}

output "storage_share_name" {
  value = azurerm_storage_share.media.name
}

# Clé « passe-partout » du compte, utilisée pour le montage SMB.
# sensitive : masquée dans plan/apply/output, MAIS stockée en clair dans le state.
# ⚠️ Dette étape 06 (Key Vault / identité).
output "storage_account_key" {
  value     = azurerm_storage_account.media.primary_access_key
  sensitive = true
}
