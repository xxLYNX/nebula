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

  # Target machine (IP or hostname, not user@host)
  target_host  = var.target_host
  install_user = var.install_user

  # Flake outputs — full references to the system closure and disko partitioner
  nixos_system_attr      = var.nixos_system_attr
  nixos_partitioner_attr = var.nixos_partitioner_attr

  # SSH key contents (the module requires key content, not a file path)
  install_ssh_key    = var.install_ssh_key
  deployment_ssh_key = var.deployment_ssh_key

  # Optional behaviour controls
  build_on_remote = var.build_on_remote
  debug_logging   = var.debug_logging
}
