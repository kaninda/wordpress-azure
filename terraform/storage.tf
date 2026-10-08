resource "azurerm_storage_account" "media" {
  name  = "stwp${random_string.mysql_suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location = azurerm_resource_group.main.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false   # « accès public au blob » désactivé

  tags = local.common_tags   # adapte à ce que tu utilises déjà
}

resource "azurerm_storage_share" "media" {
  name               = "wp-uploads"        # minuscules, chiffres, tirets
  storage_account_id = azurerm_storage_account.media.id
  quota              = 1                   # Go — garde-fou du lab
  enabled_protocol   = "SMB"               # défaut, explicite pour la lecture
  access_tier        = "TransactionOptimized"
}
