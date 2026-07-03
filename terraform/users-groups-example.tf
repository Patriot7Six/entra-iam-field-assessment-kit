terraform {
  required_providers {
    azuread = { source = "hashicorp/azuread", version = "~> 3.0" }
  }
}
provider "azuread" {}
resource "azuread_group" "critical_app_finance" {
  display_name = "Group 001 - Critical App Access"
  security_enabled = true
}
