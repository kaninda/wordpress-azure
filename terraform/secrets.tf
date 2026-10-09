# ── Valeurs générées : existent le temps du run, jamais dans le state ──

# Mot de passe admin MySQL
ephemeral "random_password" "mysql_admin" {
  length           = 24
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "-_.!%" # pas de ' " \ $ # : sûrs pour PHP, shell et .my.cnf
}

# Mot de passe de l'utilisateur MySQL dédié à WordPress
ephemeral "random_password" "wp_db" {
  length           = 24
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "-_.!%" # mêmes règles que l'admin
}

# Graine des clés/salts WordPress (dérivées par Ansible)
ephemeral "random_password" "wp_salt" {
  length  = 64
  special = false # graine, pas besoin de caractères spéciaux
}

# ── Secrets Key Vault : value_wo = envoyée à Azure, jamais dans le state ──
# depends_on : rôle Officer présent à la création, retiré APRÈS les secrets au destroy

# Clé du storage (montage SMB par vm-app)
resource "azurerm_key_vault_secret" "storage_key" {
  name             = "storage-account-key"
  key_vault_id     = azurerm_key_vault.main.id
  value_wo         = azurerm_storage_account.media.primary_access_key
  value_wo_version = 1 # à incrémenter pour pousser une nouvelle valeur
  depends_on       = [azurerm_role_assignment.kv_officer_admin]
}

# Mot de passe admin MySQL
resource "azurerm_key_vault_secret" "mysql_admin" {
  name             = "mysql-admin-password"
  key_vault_id     = azurerm_key_vault.main.id
  value_wo         = ephemeral.random_password.mysql_admin.result
  value_wo_version = 1 # incrémenter AVEC administrator_password_wo_version (mysql.tf)
  depends_on       = [azurerm_role_assignment.kv_officer_admin]
}

# Mot de passe de l'utilisateur WordPress
resource "azurerm_key_vault_secret" "wp_db" {
  name             = "wp-db-password"
  key_vault_id     = azurerm_key_vault.main.id
  value_wo         = ephemeral.random_password.wp_db.result
  value_wo_version = 1
  depends_on       = [azurerm_role_assignment.kv_officer_admin]
}

# Graine des clés/salts WordPress
resource "azurerm_key_vault_secret" "wp_salt" {
  name             = "wp-salt-seed"
  key_vault_id     = azurerm_key_vault.main.id
  value_wo         = ephemeral.random_password.wp_salt.result
  value_wo_version = 1
  depends_on       = [azurerm_role_assignment.kv_officer_admin]
}
