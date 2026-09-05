{
  description = "Testing role flake - generic NixOS module fragment for test/dev machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    {
      nixosModules.default =
        { config, pkgs, lib, primaryUser, ... }:
        {
          imports = [ ../common/base.nix ];

          services.openssh.enable = true;
          security.sudo.wheelNeedsPassword = false;
        };
    };
}
