# Runs offline: mocked providers, no Azure credentials, plan only.
mock_provider "azurerm" {}
mock_provider "random" {}

variables {
  # Throwaway key generated for this test; the azurerm provider validates the
  # key format even with a mocked provider. The private key was discarded.
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDG/NjnodjYXzsFsqJkY3sLg860KXUeZUlRYLGGsV9S26Z8S2turDRm1jzZFPSlqDb82u5+RF8+eSZqI7LhIz/2oz9158Shu6n/fBLYxZBSZK2TYuhIh2X1WIzznFq6jp3WoKhEv49z3WfoNfmADFrHqGH1WgB5hxRIOloDIZBq5NT/BKDvXJPLvCWjdf+tyjieae5T8CYqYVxzaqMO0EENA88GoQqMU9/QoGMBhd2vaotkyO18zkfAunFa5H8ND/r/ghTTl5rB1vTiWmB5F7f3APWfBif2cRjS5ySnr8MidJdt8SBLR+IlcIRKWZK+K7bLiCUAe2ROfk+fLC82ECkp terraform-test-only"
}

run "plan_with_defaults" {
  command = plan

  assert {
    condition     = var.vm_size == "Standard_B2ls_v2"
    error_message = "Default VM size must have enough RAM for Keycloak + Postgres."
  }
}

run "invalid_ssh_cidr_is_rejected" {
  command = plan

  variables {
    allowed_ssh_cidrs = ["not-a-cidr"]
  }

  expect_failures = [var.allowed_ssh_cidrs]
}
