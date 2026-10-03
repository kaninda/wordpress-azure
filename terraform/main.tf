locals {
  common_tags = {
    projet = var.project
    etape  = var.etape
    owner  = var.owner
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project}"
  location = var.location
  tags     = local.common_tags
}
