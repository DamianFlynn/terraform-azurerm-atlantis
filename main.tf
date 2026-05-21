data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_key_vault_secret" "kv_secrets" {
  for_each     = var.secure_environment_variables_from_key_vault
  name         = each.value.name
  key_vault_id = each.value.key_vault_id
}

locals {
  all_secure_env_vars = merge(
    var.secure_environment_variables,
    { for k, v in data.azurerm_key_vault_secret.kv_secrets : k => v.value }
  )

  env_vars = concat(
    [for k, v in var.environment_variables : { name = k, value = v }],
    [for k, v in local.all_secure_env_vars : { name = k, secureValue = v }]
  )

  volume_mounts = [
    for vol_name, vol in var.volumes : {
      name      = vol_name
      mountPath = vol.mount_path
      readOnly  = vol.read_only
    }
  ]

  aci_volumes = [
    for vol_name, vol in var.volumes : {
      name = vol_name
      azureFile = {
        shareName          = vol.share_name
        storageAccountName = vol.storage_account_name
        storageAccountKey  = vol.storage_account_key
        readOnly           = vol.read_only
      }
    }
  ]

  repo_config_json = length(var.atlantis_repo_config_repos) > 0 ? jsonencode({
    repos = [
      for repo in var.atlantis_repo_config_repos : {
        id                     = repo.id
        apply_requirements     = repo.apply_requirements
        allowed_overrides      = repo.allowed_overrides
        allow_custom_workflows = repo.allow_custom_workflows
      }
    ]
  }) : null

  server_config_flag_map = {
    "atlantis-url"             = var.atlantis_server_config.atlantis_url
    "repo-allowlist"           = var.atlantis_server_config.repo_allowlist
    "default-tf-version"       = var.atlantis_server_config.default_tf_version
    "hide-prev-plan-comments"  = var.atlantis_server_config.hide_prev_plan_comments
    "data-dir"                 = var.atlantis_server_config.data_dir
    "log-level"                = var.atlantis_server_config.log_level
    "azuredevops-user"         = var.atlantis_server_config.azuredevops_user
    "azuredevops-webhook-user" = var.atlantis_server_config.azuredevops_webhook_user
    "repo-config-json"         = local.repo_config_json
    "repo-config"              = var.atlantis_server_config.repo_config
  }

  atlantis_command = concat(
    ["atlantis", "server"],
    [
      for flag, value in local.server_config_flag_map :
      "--${flag}=${value}" if value != null
    ]
  )
}

resource "azapi_resource" "container_group" {
  type      = "Microsoft.ContainerInstance/containerGroups@2023-05-01"
  name      = var.name
  location  = var.location
  parent_id = data.azurerm_resource_group.this.id
  tags      = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.atlantis.id]
  }

  body = {
    properties = {
      containers = [{
        name = "atlantis"
        properties = {
          image   = var.atlantis_image
          command = local.atlantis_command
          resources = {
            requests = {
              cpu        = var.cpu
              memoryInGB = var.memory_gb
            }
          }
          ports                = [{ port = 4141, protocol = "TCP" }]
          environmentVariables = local.env_vars
          volumeMounts         = local.volume_mounts
        }
      }]
      osType  = "Linux"
      subnetIds = [{ id = var.subnet_id }]
      volumes = local.aci_volumes
      restartPolicy = "Always"
      ipAddress = {
        type  = "Private"
        ports = [{ port = 4141, protocol = "TCP" }]
      }
      diagnostics = var.log_analytics_workspace_id != null ? {
        logAnalytics = {
          workspaceId  = var.log_analytics_workspace_id
          workspaceKey = var.log_analytics_workspace_key
        }
      } : null
    }
  }

  # secureValue, storageAccountKey, and workspaceKey are write-only in ARM:
  # GET responses return null for these fields, which would cause perpetual diffs.
  # Rotate secrets by running: terraform apply -replace=module.atlantis.azapi_resource.container_group
  lifecycle {
    ignore_changes = [
      body.properties.containers[0].properties.environmentVariables,
      body.properties.volumes,
      body.properties.diagnostics,
    ]
  }

  depends_on = [azurerm_role_assignment.atlantis]
}
