# nebula - the factory

Single source of truth for all IT devices.

## Phase 0: testbed
1. Boot spare device to NixOS live ISO → `systemctl start sshd`
2. Update `terraform/main.tf` with live ISO IP
3. `cd terraform && terraform init && terraform apply`
4. After reboot: `colmena apply --on testbed`
