module "testbed" {
  source = "github.com/nix-community/nixos-anywhere//terraform/all-in-one"

  target_host = "root@192.168.50.224"   # ← CHANGE THIS

  flake = ".."                                 # points at the root flake
  flake_attr = "testbed"

  ssh_options = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
}
