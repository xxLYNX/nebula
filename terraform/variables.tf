variable "target_host" {
  description = "SSH target for nixos-anywhere / nixos-remote in the form user@host or user@ip. No default so a caller must provide it (prevents accidental applies)."
  type        = string

  validation {
    condition     = length(trimspace(var.target_host)) > 0
    error_message = "target_host must be a non-empty string like 'root@192.168.50.224' or 'voyager@my-laptop.local'."
  }
}

variable "ssh_key_path" {
  description = "Path to the private SSH key used to authenticate to the target. This can be a path on the machine running terraform (CI runner or your laptop)."
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "ssh_options" {
  description = "Additional ssh options to pass when nixos-anywhere/terraform module invokes ssh."
  type        = string
  default     = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
}

variable "ssh_private_key" {
  description = "Optional private key contents (PEM). Use only when you prefer embedding the key material (e.g., in CI via protected variable). Prefer using `ssh_key_path` instead. If provided the module may use this value. Marked sensitive downstream when used."
  type        = string
  default     = null
  nullable    = true
}

variable "flake" {
  description = "Path or URL to the root flake. Defaults to one level up from the terraform module (assumes repository layout where terraform is under the repo)."
  type        = string
  default     = ".."
}

variable "flake_attr" {
  description = "The flake attribute corresponding to the host to deploy (nixosConfigurations.<host>)."
  type        = string
  default     = "testbed"

  validation {
    condition     = length(trimspace(var.flake_attr)) > 0
    error_message = "flake_attr must be a non-empty string (e.g. 'testbed')."
  }
}

# Optional: control whether terraform should attempt to run remote apply or just plan
variable "apply_mode" {
  description = "Controls whether to run an actual apply (true) or only produce a plan/dry-run (false). Consumers/CI can set this to false for gating."
  type        = bool
  default     = true
}
