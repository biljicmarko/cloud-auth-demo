# Runs offline: mocked providers, no Azure credentials, plan only.
mock_provider "azurerm" {}
mock_provider "random" {}

variables {
  name     = "test"
  location = "westeurope"
}

run "only_http_is_public_by_default" {
  command = plan

  module {
    source = "./modules/network"
  }

  assert {
    condition     = azurerm_network_security_rule.http.destination_port_range == "80"
    error_message = "HTTP rule must open port 80."
  }

  assert {
    condition     = length(azurerm_network_security_rule.ssh) == 0
    error_message = "No permanent SSH rule may exist when allowed_ssh_cidrs is empty."
  }
}

run "ssh_limited_to_allowed_cidrs" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    allowed_ssh_cidrs = ["203.0.113.10/32"]
  }

  assert {
    condition     = toset(azurerm_network_security_rule.ssh[0].source_address_prefixes) == toset(["203.0.113.10/32"])
    error_message = "SSH must be limited to allowed_ssh_cidrs."
  }

  assert {
    condition     = azurerm_network_security_rule.ssh[0].destination_port_range == "22"
    error_message = "SSH rule must target port 22."
  }
}
