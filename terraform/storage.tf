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

# « Annuaire » privé : stwpxxx.file.core.windows.net → IP privée du PE.
# Nom imposé par Azure pour la sous-ressource file (une faute = résolution publique).
resource "azurerm_private_dns_zone" "file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

# Rend la zone visible depuis le VNet (sinon vm-app résout toujours l'IP publique).
# azurerm 5.x : la zone est référencée par son ID (le RG est inclus dedans).
# Pas d'auto-registration : les enregistrements sont écrits par le PE, pas par les VMs.
resource "azurerm_private_dns_zone_virtual_network_link" "file" {
  name                 = "link-file"
  private_dns_zone_id  = azurerm_private_dns_zone.file.id
  virtual_network_id   = azurerm_virtual_network.main.id
  registration_enabled = false
}

# Porte privée vers le storage : une NIC avec une IP de snet-pe.
# 💰 Facturé à l'heure + au Go traité.
resource "azurerm_private_endpoint" "file" {
  name                = "pe-storage-file"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.pe.id

  private_service_connection {
    name                           = "psc-storage-file"
    private_connection_resource_id = azurerm_storage_account.media.id
    subresource_names              = ["file"] # un PE par sous-ressource : ce PE ne couvre pas le Blob
    is_manual_connection           = false    # même subscription : approbation automatique
  }

  # Crée automatiquement l'enregistrement A du storage dans la zone privée.
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.file.id]
  }

  tags = local.common_tags
}
