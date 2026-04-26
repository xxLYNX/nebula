{ ... }: {
  # Host-level configuration for testbed
  #
  # Note: the root flake composes home-manager into each host by adding
  # `home-manager.nixosModules.home-manager` into imports automatically.
  # This file demonstrates including the host hardware config and shows an
  # example (commented) of how to include home-manager directly when evaluating
  # this file standalone.
  imports = [
    ./hardware-configuration.nix
    # Example: to include home-manager directly when evaluating this file
    # outside the top-level flake, uncomment and adjust the following line:
    # home-manager.nixosModules.home-manager
  ];
}
