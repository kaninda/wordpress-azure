data "azurerm_subscription" "current" {}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-wordpress-azure"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30  # minimum autorisé
  daily_quota_gb      = 0.1 # disjoncteur : collecte stoppée au-delà, reset quotidien
  tags                = local.common_tags
}

resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "diag-kv-to-law"
  target_resource_id         = azurerm_key_vault.main.id               # source
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id # destination
  enabled_log {
    category = "AuditEvent" # qui lit quel secret
  }
}

# Canal : Activity log → workspace
resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "diag-activitylog-to-law"
  target_resource_id         = data.azurerm_subscription.current.id    # source
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id # destination

  enabled_log {
    category = "Administrative" # création, suppression, modif NSG
  }
}

