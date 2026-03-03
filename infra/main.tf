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

  # Authentication intentionally omitted for this exercise.
  # In production this would use managed identity or CI/CD OIDC.
}

locals {
  # Map environment to realm for consistent naming.
  realm_by_env = {
    dev  = "shire"
    prod = "gondor"
  }

  realm = local.realm_by_env[var.environment]

  # Common governance tags
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
  # Environment-specific RG to prevent clashes
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = local.common_tags
}

# -----------------------------
# Networking (VNet + Subnet)
# -----------------------------

resource "azurerm_virtual_network" "middleearth" {
  name                = "vnet-${local.realm}-${var.environment}"
  resource_group_name = azurerm_resource_group.middleearth.name
  location            = azurerm_resource_group.middleearth.location

  
  # Replaced hardcoded CIDR with environment-specific mapping
  # Prevent IP conflicts between dev and prod
  address_space = var.vnet_address_space[var.environment]

  tags = local.common_tags
}

resource "azurerm_subnet" "shire_app" {
  name                 = "snet-${local.realm}-app-${var.environment}"
  resource_group_name  = azurerm_resource_group.middleearth.name
  virtual_network_name = azurerm_virtual_network.middleearth.name

  
  # Fixed invalid subnet (previously outside VNet range)
  # Now mapped per environment
  address_prefixes = var.subnet_address_prefix[var.environment]
}

# -----------------------------
# App Service Plan + App
# -----------------------------

resource "azurerm_app_service_plan" "shire_plan" {
  name                = "asp-${local.realm}-${var.environment}"
  resource_group_name = azurerm_resource_group.middleearth.name
  location            = azurerm_resource_group.middleearth.location
  kind                = "Linux"

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

  
  # Enforced HTTPS to improve baseline security
  https_only = true

  site_config {
    linux_fx_version = "DOTNETCORE|8.0"
  }

  # Using system-assigned identity (will wire in Step 2)
  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
    "REALM"                    = local.realm
    "ENVIRONMENT"              = var.environment
  }

  tags = local.common_tags
}

# -----------------------------
# Managed Identity (placeholder)
# -----------------------------

# Placeholder user-assigned identity.
# Currently not attached to the App Service.
# System-assigned identity is used for simplicity
resource "azurerm_user_assigned_identity" "shire_api" {
  name                = "uai-${local.realm}-api-${var.environment}"
  resource_group_name = azurerm_resource_group.middleearth.name
  location            = azurerm_resource_group.middleearth.location
  tags                = local.common_tags
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
