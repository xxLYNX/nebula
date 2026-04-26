output "target_host" {
  description = "Echoes the SSH target provided to the module (user@host or user@ip)."
  value       = var.target_host
}

output "ssh_command" {
  description = "Suggested SSH command to access the target using the configured ssh options."
  value       = "ssh ${var.ssh_options} ${var.target_host}"
}

output "ssh_key_path" {
  description = "Path on the runner to the SSH private key used for authentication (if provided). Prefer using protected variables or an external secret store for key material."
  value       = var.ssh_key_path
}

output "flake_reference" {
  description = "The flake path and attribute that will be used by nixos-anywhere (for auditing)."
  value       = "${var.flake}#${var.flake_attr}"
}

output "apply_mode" {
  description = "Whether the module is configured to perform an actual apply (true) or operate in plan/dry-run mode (false). Useful for CI gating."
  value       = var.apply_mode
}
