
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-wordpress-azure"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30                # minimum autorisé
  daily_quota_gb      = 0.1               # disjoncteur : collecte stoppée au-delà, reset quotidien
  tags                = local.common_tags 
}
