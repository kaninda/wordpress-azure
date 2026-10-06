resource "azurerm_public_ip" "lb" {
  name                = "pip-lb-${var.project}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_lb" "main" {
  location            = azurerm_resource_group.main.location
  name                = "lb-${var.project}"
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  tags                = local.common_tags
  frontend_ip_configuration {
    name                 = "fe-public"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "app" {
  name            = "bep-app"
  loadbalancer_id = azurerm_lb.main.id
}

resource "azurerm_network_interface_backend_address_pool_association" "app" {
  network_interface_id    = azurerm_network_interface.app.id
  ip_configuration_name   = azurerm_network_interface.app.ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.app.id
}

