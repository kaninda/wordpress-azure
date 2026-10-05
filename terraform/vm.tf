# IP publique de la jumpbox
resource "azurerm_public_ip" "jumpbox" {
  name                = "pip-jumpbox-${var.project}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# Carte réseau de la jumpbox NIC
resource "azurerm_network_interface" "jumpbox" {
  name                           = "nic-jumpbox-${var.project}"
  location                       = azurerm_resource_group.main.location
  resource_group_name            = azurerm_resource_group.main.name
  accelerated_networking_enabled = true
  tags                           = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.jumpbox.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox.id
  }
}

# VM - Jumpbox
resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                  = "vm-jumpbox-${var.project}"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  size                  = "Standard_D2als_v6"
  network_interface_ids = [azurerm_network_interface.jumpbox.id]
  tags                  = local.common_tags

  # Choix du point 2
  disk_controller_type = "NVMe"
  secure_boot_enabled  = true
  vtpm_enabled         = true

  # Accès : clé SSH uniquement
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = local.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

# Carte réseau de la snet-app NIC
resource "azurerm_network_interface" "app" {
  name                           = "nic-app-${var.project}"
  location                       = azurerm_resource_group.main.location
  resource_group_name            = azurerm_resource_group.main.name
  accelerated_networking_enabled = true
  tags                           = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
  }
}

# VM - app
resource "azurerm_linux_virtual_machine" "app" {
  name                  = "vm-app-${var.project}"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  size                  = "Standard_D2als_v6"
  network_interface_ids = [azurerm_network_interface.app.id]
  tags                  = local.common_tags

  # Choix du point 2
  disk_controller_type = "NVMe"
  secure_boot_enabled  = true
  vtpm_enabled         = true

  # Accès : clé SSH uniquement
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = local.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
