{
  description = "nebula root flake - inventory-driven NixOS config with Colmena";

  inputs = {
    # Pinned to known-good commits (April 2026) to bypass GitHub CDN flakiness
    nixpkgs.url = "github:NixOS/nixpkgs/b86751bc4085f48661017fa226dee99fab6c651b";

    colmena.url = "git+https://github.com/zhaofengli/colmena";
    colmena.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "git+https://github.com/nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "git+https://github.com/Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Packs as nested flakes
    testing = {
      url = "path:./profiles/roles/testing";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    security-host = {
      url = "path:./profiles/roles/security-host";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, colmena, disko, sops-nix, ... } @ inputs:
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
