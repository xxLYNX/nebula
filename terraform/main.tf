# Terraform wrapper for nixos-anywhere (all-in-one module).
# This file uses variables declared in variables.tf so nothing is hard-coded.
#
# Usage examples:
#  - terraform init
#  - terraform plan -var 'target_host=root@192.168.50.224' -var 'ssh_key_path=/home/me/.ssh/id_rsa'
#  - terraform apply -var 'target_host=root@192.168.50.224' -var 'ssh_key_path=/home/me/.ssh/id_rsa'
#
# Notes:
#  - Prefer providing `ssh_key_path` (path on the runner). If you must inject key contents from CI,
#    set `ssh_private_key` (sensitive) and the module will receive it (default null).
#  - `flake` defaults to the repository root (\"..\") and `flake_attr` defaults to \"testbed\".
#  - Keep secrets out of git; use protected CI variables or an external secret store.

module "testbed" {
  source = "github.com/nix-community/nixos-anywhere//terraform/all-in-one"

  # Core runtime inputs (parameterized)
  target_host = var.target_host
  flake       = var.flake
  flake_attr  = var.flake_attr

  # SSH configuration: prefer path; ssh_private_key can be used for CI-injected key material.
  ssh_options      = var.ssh_options
  ssh_key_path     = var.ssh_key_path
  ssh_private_key  = var.ssh_private_key

  # If the module supports other flags (e.g., timeouts / verbose) you can pass them here.
  # Example (uncomment if the module supports it):
  # ssh_timeout = "30s"
}
