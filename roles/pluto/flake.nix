{
  description = "pluto role flake - primary workstation NixOS module fragment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    {
      nixosModules.default =
        { config, pkgs, lib, ... }:
        {
          imports = [ ../common/base.nix ];

          services.openssh = {
            enable = true;
            openFirewall = false;
            settings = {
              PasswordAuthentication = false;
              PermitRootLogin = "no";
            };
          };
          security.sudo.wheelNeedsPassword = true;
        };
    };
}
