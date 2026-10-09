provider "azurerm" {
  features {
    key_vault {
      # Vault
      purge_soft_delete_on_destroy    = true # destroy → vault purgé, nom libéré
      recover_soft_deleted_key_vaults = true # apply → récupère un vault resté en corbeille
      # Secrets
      purge_soft_deleted_secrets_on_destroy = true # destroy → secret purgé
      recover_soft_deleted_secrets          = true # apply → récupère un secret resté en corbeille
    }
  }
}
