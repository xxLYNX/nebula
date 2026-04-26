variable "target_host" {
  description = "IP address or hostname of the target machine. No default to prevent accidental applies."
  type        = string

  validation {
    condition     = length(trimspace(var.target_host)) > 0
    error_message = "target_host must be a non-empty IP or hostname, e.g. '192.168.50.100'."
  }
}

variable "install_user" {
  description = "SSH user for connecting during installation (live ISO user, typically 'root' or 'nixos')."
  type        = string
  default     = "root"
}

variable "nixos_system_attr" {
  description = "Full flake reference to the NixOS system closure to install."
  type        = string
  default     = "github:xxLYNX/nebula#nixosConfigurations.testbed.config.system.build.toplevel"
}

variable "nixos_partitioner_attr" {
  description = "Full flake reference to the disko partitioner script (provided by the disko NixOS module)."
  type        = string
  default     = "github:xxLYNX/nebula#nixosConfigurations.testbed.config.system.build.diskoNoDeps"
}

variable "install_ssh_key" {
  description = "Contents of the SSH private key used during installation. Pass with: -var=\"install_ssh_key=$(cat ~/.ssh/id_ed25519)\""
  type        = string
  sensitive   = true
  default     = null
}

variable "deployment_ssh_key" {
  description = "Contents of the SSH private key used after installation. Pass with: -var=\"deployment_ssh_key=$(cat ~/.ssh/id_ed25519)\""
  type        = string
  sensitive   = true
  default     = null
}

variable "build_on_remote" {
  description = "Build the NixOS closure on the target instead of locally. Useful when running terraform from a non-Linux machine."
  type        = bool
  default     = false
}

variable "debug_logging" {
  description = "Enable verbose debug logging in nixos-anywhere."
  type        = bool
  default     = false
}
