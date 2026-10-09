# Tenant et identité de celui qui lance Terraform (toi, via az login)
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  # Nom global unique, 3 à 24 caractères, lettres, chiffres et tirets
  # On réutilise le suffixe aléatoire du storage → nouveau nom à chaque session
  name                = "kv-wp-${random_string.mysql_suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard" # premium = clés HSM, inutile ici

  # Modèle RBAC (et non access policies)
  rbac_authorization_enabled = true

  # Corbeille : 7 jours minimum, purge autorisée (lab)
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  # Accès réseau public : tout est refusé sauf ton IP
  public_network_access_enabled = true # nécessaire pour que ip_rules s'applique
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = [var.admin_ip]
  }
  tags = local.common_tags
}

# Zone DNS privée du Key Vault
resource "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# Lien zone ↔ VNet (sans auto-registration)
resource "azurerm_private_dns_zone_virtual_network_link" "kv" {
  name                 = "link-kv"
  private_dns_zone_id  = azurerm_private_dns_zone.kv.id
  virtual_network_id   = azurerm_virtual_network.main.id
  registration_enabled = false
  tags                 = local.common_tags
}

# PE dans snet-pe, sous-ressource "vault"
resource "azurerm_private_endpoint" "kv" {
  name                = "pe-keyvault"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.pe.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "psc-keyvault"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"] # storage : "file"
    is_manual_connection           = false
  }

  # Crée l'enregistrement A automatiquement dans la zone
  private_dns_zone_group {
    name                 = "kv-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv.id]
  }
}

# Toi : lire et écrire les secrets (Terraform les écrit depuis ton Mac)
resource "azurerm_role_assignment" "kv_officer_admin" {
  scope                = azurerm_key_vault.main.id # portée = ce vault seulement
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# vm-app : lecture seule des secrets
resource "azurerm_role_assignment" "kv_user_app" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.app.identity[0].principal_id
}
