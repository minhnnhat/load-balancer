locals {
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_lb" "az_lb_internal" {
  resource_group_name = local.resource_group_name
  location            = local.location

  name = var.name
  sku  = "Standard"

  dynamic "frontend_ip_configuration" {
    # for_each = var.lb_internal
    for_each = lookup(var.lb_internal, "private_lb", tomap({}))
    iterator = frontend
    content {
      name                          = frontend.key
      subnet_id                     = var.subnet_ids
      private_ip_address_allocation = "Static"
      private_ip_address            = lookup(frontend.value, "fe_privateip", "")
      private_ip_address_version    = "IPv4"
    }
  }
}

resource "azurerm_lb_backend_address_pool" "az_lb_bepool" {
  loadbalancer_id = azurerm_lb.az_lb_internal.id
  name            = "BackEndAddressPool"
}

resource "azurerm_network_interface_backend_address_pool_association" "az_vnet_bepool" {
  for_each                = var.network_interface_ids
  network_interface_id    = each.value
  ip_configuration_name   = "ipconfig"
  backend_address_pool_id = azurerm_lb_backend_address_pool.az_lb_bepool.id
}

resource "azurerm_lb_probe" "az_lbprobe" {
  resource_group_name = local.resource_group_name
  loadbalancer_id     = azurerm_lb.az_lb_internal.id

  for_each = lookup(var.lb_internal, "private_lb", tomap({}))
  name     = lookup(each.value, "probe_name", "")
  port     = lookup(each.value, "probe_port", "")
}

resource "azurerm_lb_rule" "az_lbrule" {
  resource_group_name = local.resource_group_name
  loadbalancer_id     = azurerm_lb.az_lb_internal.id

  for_each = lookup(var.lb_internal, "private_lb", tomap({}))
  name                           = lookup(each.value, "rule_name", "")
  protocol                       = "Tcp"
  frontend_port                  = lookup(each.value, "rule_feport", "")
  backend_port                   = lookup(each.value, "rule_beport", "")
  frontend_ip_configuration_name = each.key
  backend_address_pool_id        = azurerm_lb_backend_address_pool.az_lb_bepool.id
  probe_id                       = azurerm_lb_probe.az_lbprobe[each.key].id
  enable_floating_ip             = true
}