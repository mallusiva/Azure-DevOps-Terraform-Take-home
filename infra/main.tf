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
# Dynamically retrieves tenant and subscription information.
# Avoids hardcoding tenant_id in Key Vault configuration.
data "azurerm_client_config" "current" {}

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

  # Using system-assigned identity for secure Key Vault access
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

  # Standard SKU suitable for this scenario (non-HSM).
  sku_name = "standard"

  # Removed hardcoded tenant_id.
  # Now dynamically retrieved from current Azure context.
  tenant_id = data.azurerm_client_config.current.tenant_id

  # Disable public network access to improve security posture.
  # In production this would typically allow only private endpoints.
  public_network_access_enabled = false

  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  tags = local.common_tags
}

# Grant App Service managed identity permission to read secrets.
# Uses system-assigned identity from the App Service.
resource "azurerm_key_vault_access_policy" "shire_api" {
  key_vault_id = azurerm_key_vault.one_ring.id

  tenant_id = data.azurerm_client_config.current.tenant_id

  # Uses system-assigned identity principal ID.
  object_id = azurerm_app_service.shire_api.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}