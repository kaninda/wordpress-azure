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
