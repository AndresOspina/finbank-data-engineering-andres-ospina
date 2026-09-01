terraform {
  backend "azurerm" {
    resource_group_name  = "rg-finbank-dev"
    storage_account_name = "stfinbankdev2896"
    container_name       = "tfstate"
    key                  = "finbank-dev.terraform.tfstate"

    use_cli          = true
    use_azuread_auth = true
  }
}