variable "environment" {
  description = "Deployment environment, e.g. dev (Shire) or prod (Gondor)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "uksouth"
}

variable "project_name" {
  description = "Logical project name used for naming resources."
  type        = string
  default     = "middleearth"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    project    = "middleearth"
    managed_by = "adroit"
    cost_centre = "fellowship"
  }
}

# -----------------------------------------
# Environment-specific networking settings
# -----------------------------------------
# This is to prevent IP conflicts between dev and prod
# and Separate CIDR ranges per environment 

variable "vnet_address_space" {
  description = "VNet CIDR range per environment."
  type        = map(list(string))

  default = {
    dev  = ["10.10.0.0/16"]
    prod = ["10.20.0.0/16"]
  }
}

# Environment-specific subnet ranges
# this is to ensure subnet is valid within respective VNet
variable "subnet_address_prefix" {
  description = "Subnet CIDR per environment."
  type        = map(list(string))

  default = {
    dev  = ["10.10.1.0/24"]
    prod = ["10.20.1.0/24"]
  }
}