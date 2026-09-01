variable "subscription_id" {
  description = "ID de la suscripcion de Azure"
  type        = string
}

variable "resource_group_name" {
  description = "Nombre del Resource Group"
  type        = string
  default     = "rg-finbank-dev"
}

variable "location" {
  description = "Region de Azure"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Ambiente del proyecto"
  type        = string
  default     = "dev"
}