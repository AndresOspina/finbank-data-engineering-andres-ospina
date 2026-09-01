output "resource_group_name" {
  description = "Nombre del Resource Group"
  value       = azurerm_resource_group.finbank.name
}

output "resource_group_location" {
  description = "Region del Resource Group"
  value       = azurerm_resource_group.finbank.location
}

output "storage_account_name" {
  description = "Nombre del Storage Account ADLS Gen2"
  value       = azurerm_storage_account.finbank.name
}

output "storage_account_id" {
  description = "ID del Storage Account"
  value       = azurerm_storage_account.finbank.id
}

output "key_vault_name" {
  description = "Nombre del Key Vault"
  value       = azurerm_key_vault.finbank.name
}

output "data_factory_name" {
  description = "Nombre de Azure Data Factory"
  value       = azurerm_data_factory.finbank.name
}

output "log_analytics_workspace_name" {
  description = "Nombre del workspace de Log Analytics"
  value       = azurerm_log_analytics_workspace.finbank.name
}

output "action_group_name" {
  description = "Nombre del Action Group"
  value       = azurerm_monitor_action_group.finbank.name
}