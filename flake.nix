{
  description = "nebula root flake - inventory-driven NixOS config with Colmena";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    colmena.url = "github:zhaofengli/colmena";
    colmena.inputs.nixpkgs.follows = "nixpkgs";

    # Core shared modules used by every host (kept in root to avoid duplication)
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Packs as nested flakes — they can declare their own extra inputs
    testing = {
      url = "path:./profiles/roles/testing";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    security-host = {
      url = "path:./profiles/roles/security-host";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, colmena, ... } @ inputs:
  let
    inventory = builtins.fromJSON (builtins.readFile ./inventory/machines.json);

    mkHost = name: machine: {
      imports = [
        ./hosts/${name}/configuration.nix
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
      ] ++ (map (pack: inputs.${pack}.nixosModules.default) machine.packs);

      _module.args = {
        inherit inputs;
        primaryUser = machine.primaryUser;
      };

      networking.hostName = machine.hostname;
    };
  in {
    colmena = {
      meta = {
        nixpkgs = import nixpkgs { system = "x86_64-linux"; };
        specialArgs = inputs;
      };
    } // builtins.mapAttrs mkHost inventory.machines;

    nixosConfigurations = colmena;
  };
}
