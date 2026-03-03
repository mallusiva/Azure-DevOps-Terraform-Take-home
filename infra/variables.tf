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
