{
  description = "Role flake for security-host. This role delegates to the reusable module living in ../../.. /modules/security-host so role compositions stay lightweight and composable.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Import the reusable security-host module from the repository's modules directory.
    # Relative path from `profiles/roles/security-host` -> `modules/security-host` is ../../../modules/security-host
    securityModule = {
      url = "path:../../../modules/security-host";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, securityModule, ... }: {
    # Expose a NixOS module fragment under `nixosModules.default`.
    # The top-level flake should pass `_module.args` including `primaryUser` and `machine`.
    #
    # This flake simply forwards the module call to the implementation in `modules/security-host`.
    nixosModules.default = { config, pkgs, primaryUser, machine, ... }:
      let
        impl = securityModule.nixosModules.default;
      in
        impl { inherit config pkgs primaryUser machine; };
  };
}
