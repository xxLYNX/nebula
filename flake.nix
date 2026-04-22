{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    colmena.url = "github:zhaofengli/colmena";
    colmena.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko/latest";  # declarative disks
    disko.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    # ... add headscale, flux, etc. later
  };

  outputs = { self, nixpkgs, colmena, disko, ... } @ inputs: {
    colmena = {
      meta = {
        nixpkgs = import nixpkgs { system = "x86_64-linux"; };
        specialArgs = { inherit inputs; };
      };

      # Example first host — we'll expand this
      "storage-server01" = { pkgs, ... }: {
        imports = [
          ./hosts/storage-server01/configuration.nix
          disko.nixosModules.disko  # ← enables disko
        ];
      };
    };

    # Optional: nixos-anywhere friendly configs
    nixosConfigurations = colmena;
  };
}
