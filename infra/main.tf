terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

data "azurerm_client_config" "current" {}

# Resource Group

resource "azurerm_resource_group" "finbank" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    project     = "finbank-data-engineering"
    environment = var.environment
  }
}

# Storage Account - ADLS Gen2

resource "azurerm_storage_account" "finbank" {
  name                     = "stfinbank${var.environment}2896"
  resource_group_name      = azurerm_resource_group.finbank.name
  location                 = azurerm_resource_group.finbank.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  is_hns_enabled                   = true
  allow_nested_items_to_be_public = false

  tags = {
    project     = "finbank-data-engineering"
    environment = var.environment
  }
}

# Contenedores Medallion

resource "azurerm_storage_container" "bronze" {
  name                  = "bronze"
  storage_account_id    = azurerm_storage_account.finbank.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "silver" {
  name                  = "silver"
  storage_account_id    = azurerm_storage_account.finbank.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "gold" {
  name                  = "gold"
  storage_account_id    = azurerm_storage_account.finbank.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.finbank.id
  container_access_type = "private"
}

# Key Vault

resource "azurerm_key_vault" "finbank" {
  name                = "kv-finbank-${var.environment}-001"
  location            = azurerm_resource_group.finbank.location
  resource_group_name = azurerm_resource_group.finbank.name

  tenant_id = data.azurerm_client_config.current.tenant_id
  sku_name  = "standard"

  soft_delete_retention_days = 7
  purge_protection_enabled    = false

  tags = {
    project     = "finbank-data-engineering"
    environment = var.environment
  }
}

# Azure Data Factory

resource "azurerm_data_factory" "finbank" {
  name                = "adf-finbank-${var.environment}-001"
  location            = azurerm_resource_group.finbank.location
  resource_group_name = azurerm_resource_group.finbank.name

  identity {
    type = "SystemAssigned"
  }

  tags = {
    project     = "finbank-data-engineering"
    environment = var.environment
  }
}

# Log Analytics

resource "azurerm_log_analytics_workspace" "finbank" {
  name                = "law-finbank-${var.environment}-001"
  location            = azurerm_resource_group.finbank.location
  resource_group_name = azurerm_resource_group.finbank.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    project     = "finbank-data-engineering"
    environment = var.environment
  }
}

# Action Group

resource "azurerm_monitor_action_group" "finbank" {
  name                = "ag-finbank-${var.environment}-001"
  resource_group_name = azurerm_resource_group.finbank.name
  short_name          = "finbankag"

  tags = {
    project     = "finbank-data-engineering"
    environment = var.environment
  }
}

# Alerta del Storage Account

resource "azurerm_monitor_metric_alert" "storage_transactions" {
  name                = "alert-finbank-${var.environment}-storage-transactions"
  resource_group_name = azurerm_resource_group.finbank.name
  scopes              = [azurerm_storage_account.finbank.id]

  description = "Alerta de actividad elevada en el Storage Account"

  criteria {
    metric_namespace = "Microsoft.Storage/storageAccounts"
    metric_name      = "Transactions"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 1000
  }

  action {
    action_group_id = azurerm_monitor_action_group.finbank.id
  }

  tags = {
    project     = "finbank-data-engineering"
    environment = var.environment
  }
}