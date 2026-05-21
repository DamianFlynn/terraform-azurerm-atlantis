output "container_group_id" {
  description = "Resource ID of the ACI container group"
  value       = azapi_resource.container_group.id
}

output "identity_id" {
  description = "Resource ID of the User-Assigned Managed Identity"
  value       = azurerm_user_assigned_identity.atlantis.id
}

output "identity_principal_id" {
  description = "Object (principal) ID of the MSI — use for additional role assignments outside this module"
  value       = azurerm_user_assigned_identity.atlantis.principal_id
}

output "identity_client_id" {
  description = "Client ID of the MSI — pass as ARM_CLIENT_ID when using MSI auth inside Atlantis"
  value       = azurerm_user_assigned_identity.atlantis.client_id
}
