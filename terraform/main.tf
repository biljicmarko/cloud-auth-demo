terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state in Azure Storage. Account/container/key are passed with
  # -backend-config in CI (see README "Bootstrap"), so `destroy` and repeated
  # `apply` runs see the same state.
  backend "azurerm" {
    use_oidc         = true
    use_azuread_auth = true
  }
}

# Credentials and subscription come from ARM_* environment variables
# (OIDC federation in GitHub Actions, or `az login` locally).
provider "azurerm" {
  features {}
}

locals {
  project = "cloud-auth-demo"
}

module "network" {
  source            = "./modules/network"
  name              = local.project
  location          = var.location
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

module "vm" {
  source              = "./modules/vm"
  name                = local.project
  location            = module.network.location
  resource_group_name = module.network.resource_group_name
  subnet_id           = module.network.subnet_id
  public_ip_id        = module.network.public_ip_id
  size                = var.vm_size
  admin_username      = var.admin_username
  public_key          = var.public_key
}
