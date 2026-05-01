{
  description = "Module registry — aggregates all composable nebula modules as named nixosModules outputs. The root flake takes a single 'registry' input instead of one input per module. Adding a new module to the fleet only requires editing this file, not the root flake.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    desktop = {
      url = "path:../desktop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    web-utils = {
      url = "path:../web-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    maintenance = {
      url = "path:../maintenance";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    security-host = {
      url = "path:../security-host";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, desktop, web-utils, maintenance, security-host, ... }: {
    # Each composable module is re-exported by name.
    # mkHost resolves: inputs.registry.nixosModules.${mod}
    nixosModules = {
      desktop       = desktop.nixosModules.default;
      web-utils     = web-utils.nixosModules.default;
      maintenance   = maintenance.nixosModules.default;
      security-host = security-host.nixosModules.default;
    };
  };
}
