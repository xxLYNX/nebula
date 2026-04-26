output "target_host" {
  description = "The target host provided to nixos-anywhere."
  value       = var.target_host
}

output "nixos_system_attr" {
  description = "The NixOS system flake reference that was installed."
  value       = var.nixos_system_attr
}

output "nixos_partitioner_attr" {
  description = "The disko partitioner flake reference that was used."
  value       = var.nixos_partitioner_attr
}

output "install_user" {
  description = "The SSH user used during installation."
  value       = var.install_user
}

output "build_on_remote" {
  description = "Whether the closure was built on the remote machine."
  value       = var.build_on_remote
}
