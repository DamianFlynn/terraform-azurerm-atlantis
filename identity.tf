resource "azurerm_user_assigned_identity" "atlantis" {
  name                = "${var.name}-msi"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "atlantis" {
  for_each = {
    for idx, ra in var.role_assignments :
    "${replace(ra.role_definition_name, " ", "-")}-${idx}" => ra
  }
  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id         = azurerm_user_assigned_identity.atlantis.principal_id
}
