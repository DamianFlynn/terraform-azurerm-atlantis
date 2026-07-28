# Proves the --repo-config / --repo-config-json mutual-exclusion precondition.
#
# Atlantis refuses to start when given both flags, and ACI accepts the apply
# regardless — so the failure would surface as a crash-looping container, not a
# failed plan. This test is the reason that is caught at plan time instead.
#
# Providers are mocked: the precondition is pure input logic and must be
# provable without an Azure subscription.

mock_provider "azurerm" {
  # azapi validates parent_id as a real ARM resource ID, and the generated mock
  # value is a bare random string. Pin it to something well-formed.
  mock_data "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
    }
  }
}

mock_provider "azapi" {}

variables {
  name                = "atlantis"
  resource_group_name = "rg-test"
  location            = "westeurope"
  subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet/subnets/snet"
}

# ── The regression: a half-finished migration to the file-based config ───────
# repo_config set while the JSON list is still populated. Before the
# precondition this applied cleanly and emitted both flags.
run "both_set_is_rejected" {
  command = plan

  variables {
    atlantis_server_config = {
      repo_config = "/atlantis/repos.yaml"
    }
    atlantis_repo_config_repos = [
      { id = "/.*/" }
    ]
  }

  expect_failures = [azapi_resource.container_group]
}

# ── The completed migration: file only, list emptied in the same change ──────
run "file_only_is_accepted" {
  command = plan

  variables {
    atlantis_server_config = {
      repo_config          = "/atlantis/repos.yaml"
      enable_policy_checks = "true"
    }
    atlantis_repo_config_repos = []
  }

  assert {
    condition     = contains(local.atlantis_command, "--repo-config=/atlantis/repos.yaml")
    error_message = "--repo-config was not emitted from atlantis_server_config.repo_config"
  }

  assert {
    condition = length([
      for f in local.atlantis_command : f if startswith(f, "--repo-config-json=")
    ]) == 0
    error_message = "--repo-config-json was emitted alongside --repo-config"
  }

  assert {
    condition     = contains(local.atlantis_command, "--enable-policy-checks=true")
    error_message = "--enable-policy-checks was not emitted"
  }
}

# ── The status quo ante: JSON list only. Must keep working untouched ─────────
run "json_only_still_works" {
  command = plan

  variables {
    atlantis_server_config     = {}
    atlantis_repo_config_repos = [
      { id = "/.*/", apply_requirements = ["approved"] }
    ]
  }

  assert {
    condition = length([
      for f in local.atlantis_command : f if startswith(f, "--repo-config-json=")
    ]) == 1
    error_message = "--repo-config-json was not emitted for the JSON-list path"
  }

  assert {
    condition = length([
      for f in local.atlantis_command : f if startswith(f, "--repo-config=")
    ]) == 0
    error_message = "--repo-config leaked in when no file path was configured"
  }
}

# ── Policy checks off unless explicitly asked for ────────────────────────────
# Atlantis silently skips the policy_check stage when the flag is absent, so an
# accidental default here would be indistinguishable from a working guard.
run "policy_checks_absent_by_default" {
  command = plan

  variables {
    atlantis_server_config     = {}
    atlantis_repo_config_repos = []
  }

  assert {
    condition = length([
      for f in local.atlantis_command : f if startswith(f, "--enable-policy-checks")
    ]) == 0
    error_message = "--enable-policy-checks was emitted without being configured"
  }
}
