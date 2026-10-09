resource "azurerm_private_dns_zone" "mysql" {
  name                = "wp-lab.private.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                 = "link-mysql-vnet"
  private_dns_zone_id  = azurerm_private_dns_zone.mysql.id
  virtual_network_id   = azurerm_virtual_network.main.id
  registration_enabled = false
}

resource "random_string" "mysql_suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_mysql_flexible_server" "main" {
  name                              = "mysql-wp-${random_string.mysql_suffix.result}"
  resource_group_name               = azurerm_resource_group.main.name
  location                          = azurerm_resource_group.main.location
  administrator_login               = "wpadmin"
  administrator_password_wo         = ephemeral.random_password.mysql_admin.result
  administrator_password_wo_version = 2 # incrémenter AVEC celui du secret
  version                           = "8.4"
  sku_name                          = "B_Standard_B1ms"
  backup_retention_days             = 1
  delegated_subnet_id               = azurerm_subnet.data.id
  private_dns_zone_id               = azurerm_private_dns_zone.mysql.id
  tags                              = local.common_tags

  storage {
    size_gb            = 20
    auto_grow_enabled  = false
    io_scaling_enabled = false
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]
}

resource "azurerm_mysql_flexible_database" "wordpress" {
  name                = "wordpress"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}



output "mysql_fqdn" {
  value = azurerm_mysql_flexible_server.main.fqdn
}
