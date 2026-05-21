variable "name" {
  description = "Base name for resources (container group, MSI)"
  type        = string
  default     = "atlantis"
}

variable "resource_group_name" {
  description = "Resource group where all resources are deployed"
  type        = string
}

variable "location" {
  description = "Azure region (e.g. westeurope)"
  type        = string
}

variable "subnet_id" {
  description = "ID of a dedicated /28 subnet delegated to Microsoft.ContainerInstance/containerGroups"
  type        = string
}

variable "atlantis_image" {
  description = "Atlantis container image including tag"
  type        = string
  default     = "ghcr.io/runatlantis/atlantis:v0.33.0"
}

variable "cpu" {
  description = "CPU cores for the Atlantis container"
  type        = number
  default     = 1
}

variable "memory_gb" {
  description = "Memory in GiB for the Atlantis container"
  type        = number
  default     = 2
}

variable "environment_variables" {
  description = "Non-sensitive environment variables passed to the Atlantis container"
  type        = map(string)
  default     = {}
}

variable "secure_environment_variables" {
  description = "Sensitive environment variables passed to the Atlantis container (stored encrypted in state; write-only in ARM)"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "secure_environment_variables_from_key_vault" {
  description = "Sensitive environment variables resolved from Key Vault at plan time and treated as secure"
  type = map(object({
    key_vault_id = string
    name         = string
  }))
  default = {}
}

variable "volumes" {
  description = "Azure File Share volumes to mount into the container"
  type = map(object({
    mount_path           = string
    storage_account_name = string
    storage_account_key  = string
    share_name           = string
    read_only            = optional(bool, false)
  }))
  default   = {}
  sensitive = true
}

variable "atlantis_server_config" {
  description = "Atlantis server configuration — each non-null field becomes a --flag=value server arg"
  type = object({
    atlantis_url             = optional(string)
    repo_allowlist           = optional(string)
    default_tf_version       = optional(string, "v1.12.0")
    hide_prev_plan_comments  = optional(string, "true")
    data_dir                 = optional(string, "/atlantis")
    log_level                = optional(string, "info")
    azuredevops_user         = optional(string)
    azuredevops_webhook_user = optional(string)
    repo_config              = optional(string)
  })
  default = {}
}

variable "atlantis_repo_config_repos" {
  description = "Server-side repo configuration — serialised to JSON and passed as --repo-config-json"
  type = list(object({
    id                     = string
    apply_requirements     = optional(list(string), ["approved"])
    allowed_overrides      = optional(list(string), [])
    allow_custom_workflows = optional(bool, false)
  }))
  default = []
}

variable "role_assignments" {
  description = "Azure role assignments granted to the module-managed User-Assigned MSI"
  type = list(object({
    scope                = string
    role_definition_name = string
  }))
  default = []
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for ACI native log streaming (optional)"
  type        = string
  default     = null
}

variable "log_analytics_workspace_key" {
  description = "Log Analytics workspace primary shared key (optional)"
  type        = string
  default     = null
  sensitive   = true
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
