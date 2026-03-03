terraform {
  required_version = ">= 1.3.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
}

provider "azurerm" {
  features {}

  # NOTE:
  # We intentionally do NOT set subscription details here, as you are not
  # expected to run `terraform apply` for this exercise.
  #
  # In a real setup you might set:
  # - subscription_id
  # - tenant_id
  # - client_id / client_secret (or use managed identities)
}

locals {
  # Map environment to realm, used for naming and tags.
  realm_by_env = {
    dev  = "shire"
    prod = "gondor"
  }

  realm = local.realm_by_env[var.environment]

  common_tags = merge(
    var.tags,
    {
      environment = var.environment
      realm       = local.realm
    }
  )
}

# -----------------------------
# Resource Group
# -----------------------------

resource "azurerm_resource_group" "middleearth" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location

  tags = local.common_tags
}

# -----------------------------
# Networking (VNet + Subnet)
# -----------------------------

resource "azurerm_virtual_network" "middleearth" {
  name                = "vnet-${local.realm}-${var.environment}"
  resource_group_name = azurerm_resource_group.middleearth.name

  # FIXME: Make sure this address space is sensible and can be split
  # for multiple subnets and environments (dev/prod).
  address_space = [
    "10.10.0.0/16"
  ]

  location = azurerm_resource_group.middleearth.location
  tags     = local.common_tags
}

resource "azurerm_subnet" "shire_app" {
  name                 = "snet-${local.realm}-app-${var.environment}"
  resource_group_name  = azurerm_resource_group.middleearth.name
  virtual_network_name = azurerm_virtual_network.middleearth.name

  # FIXME: Ensure this subnet is a valid subset of the VNet address space.
  # Current value is intentionally suspicious.
  address_prefixes = [
    "10.20.1.0/24"
  ]
}

# -----------------------------
# App Service Plan + App
# -----------------------------

resource "azurerm_app_service_plan" "shire_plan" {
  name                = "asp-${local.realm}-${var.environment}"
  resource_group_name = azurerm_resource_group.middleearth.name
  location            = azurerm_resource_group.middleearth.location

  kind = "Linux"

  sku {
    tier = "Basic"
    size = "B1"
  }

  tags = local.common_tags
}

resource "azurerm_app_service" "shire_api" {
  name                = "app-${local.realm}-api-${var.environment}"
  resource_group_name = azurerm_resource_group.middleearth.name
  location            = azurerm_resource_group.middleearth.location
  app_service_plan_id = azurerm_app_service_plan.shire_plan.id

  # FIXME: For security, review whether HTTPS-only should be enabled.
  https_only = false

  site_config {
    linux_fx_version = "DOTNETCORE|8.0"
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
    "REALM"                    = local.realm
    "ENVIRONMENT"              = var.environment
    # TODO: In a real setup, secrets would come from Key Vault.
    # e.g. "ConnectionStrings__Database" retrieved via Key Vault reference.
  }

  tags = local.common_tags
}

# -----------------------------
# Managed Identity (optional)
# -----------------------------

# NOTE:
# We include this as a placeholder for a user-assigned identity if you
# prefer that pattern. You can either:
#  - Complete and use this identity with App Service, OR
#  - Stick to the system-assigned identity on the App Service.
#
# In either case, make sure the Key Vault access policy is correct.

resource "azurerm_user_assigned_identity" "shire_api" {
  name                = "uai-${local.realm}-api-${var.environment}"
  resource_group_name = azurerm_resource_group.middleearth.name
  location            = azurerm_resource_group.middleearth.location

  tags = local.common_tags
}

# -----------------------------
# Key Vault (One Ring)
# -----------------------------

resource "azurerm_key_vault" "one_ring" {
  name                = "kv-${local.realm}-one-ring-${var.environment}"
  resource_group_name = azurerm_resource_group.middleearth.name
  location            = azurerm_resource_group.middleearth.location

  # FIXME: Choose an appropriate SKU for this scenario.
  sku_name = "standard"

  tenant_id = "00000000-0000-0000-0000-000000000000" # FIXME: placeholder – how would this be handled in real code?

  # FIXME: Restrict network access sensibly (no wide-open pattern).
  # For this exercise, you may leave this as-is, but describe what you
  # would do in a real environment in QUESTIONS.md.

  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  tags = local.common_tags
}

# TODO:
# Wire up an access policy so that the shire-api can read secrets using its
# managed identity (system- or user-assigned). You may choose one approach
# and implement it.

# Example (incomplete, for you to fix/finish):
#
# resource "azurerm_key_vault_access_policy" "shire_api" {
#   key_vault_id = azurerm_key_vault.one_ring.id
#
#   tenant_id = azurerm_key_vault.one_ring.tenant_id
#   object_id = azurerm_app_service.shire_api.identity[0].principal_id
#
#   secret_permissions = [
#     "Get",
#     "List"
#   ]
# }

# -----------------------------
# Hints for dev/prod split
# -----------------------------
#
# - Currently, this configuration assumes a single environment via var.environment.
# - For this exercise, you can:
#   - Use different values of var.environment (dev/prod) with separate state files, OR
#   - Introduce a simple pattern using for_each or modules.
#
# - We are not prescribing one “correct” solution; we are interested in your reasoning.
#
# TODO:
#  - Extend this configuration so that a prod (Gondor) environment can be defined
#    alongside dev (Shire) with minimal duplication and sensible naming.
