# Terraform wrapper for nixos-anywhere (all-in-one module).
# This file uses variables declared in variables.tf so nothing is hard-coded.
#
# Prerequisites:
#   - Target machine booted to NixOS live ISO with sshd running (systemctl start sshd)
#   - Terraform installed on this machine (Windows/Linux/macOS)
#
# Usage from PowerShell (Windows):
#   terraform -chdir=G:/nebula/terraform init
#   $key = Get-Content $env:USERPROFILE\.ssh\id_ed25519 -Raw
#   terraform -chdir=G:/nebula/terraform apply `
#     -var="target_host=192.168.50.100" `
#     -var="install_ssh_key=$key" `
#     -var="deployment_ssh_key=$key"
#
# build_on_remote defaults to true so the NixOS closure is built on the target
# (the live ISO has Nix), not locally on Windows where Nix is unavailable.
# nixos_system_attr and nixos_partitioner_attr default to the testbed host.

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
