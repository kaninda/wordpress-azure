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

resource "azurerm_monitor_data_collection_rule" "vm_app" {
  location            = azurerm_resource_group.main.location
  name                = "dcr-vm-app"
  resource_group_name = azurerm_resource_group.main.name
  kind                = "Linux"
  destinations {
    log_analytics {
      name                  = "law"
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
    }
  }
  # Flux : Perf + Syslog → workspace
  data_flow {
    streams      = ["Microsoft-Perf", "Microsoft-Syslog"]
    destinations = ["law"]
  }
  data_sources {
    performance_counter {
      name                          = "perf"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\Processor(*)\\% Processor Time",
        "\\Memory(*)\\% Used Memory",
        "\\Logical Disk(*)\\% Used Space",
      ]
    }

    syslog {
      name           = "syslog"
      streams        = ["Microsoft-Syslog"]
      facility_names = ["auth", "authpriv", "daemon", "syslog"]
      log_levels     = ["Warning", "Error", "Critical", "Alert", "Emergency"] # peu de volume
    }
  }
  tags = local.common_tags
}

# Lien DCR ↔ vm-app
resource "azurerm_monitor_data_collection_rule_association" "vm_app" {
  name                    = "dcra-vm-app"
  target_resource_id      = azurerm_linux_virtual_machine.app.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vm_app.id
}

