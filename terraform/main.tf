terraform {
  required_version = ">= 1.9.8"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.50"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}


provider "azurerm" {
  features {}
}


locals {
  project  = "cloud-auth-demo"
  location = "westeurope"
}

module "network" {
  source   = "./modules/network"
  name     = local.project
  location = local.location
}

module "vm" {
  source              = "./modules/vm"
  name                = local.project
  location            = module.network.location
  resource_group_name = module.network.resource_group_name
  subnet_id           = module.network.subnet_id
  public_ip_id        = module.network.public_ip_id
  admin_username      = "azureuser"
  public_key          = var.public_key
}
