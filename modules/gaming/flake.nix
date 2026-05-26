{
  description = "Gaming module: Steam + Intel graphics + Proton + 32-bit support";

  inputs = {
    nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }:
  let
    pkgs = import nixpkgs { system = "x86_64-linux"; };
    lib = pkgs.lib;

    importDir = dir:
      builtins.map (name: dir + "/${name}")
        (builtins.filter (name: builtins.match ".*\.nix$" name != null)
          (builtins.attrNames
            (lib.filterAttrs (_: type: type == "regular") (builtins.readDir dir))));
  in {

    # ── System NixOS module ────────────────────────────────────────────────
    # Enables Intel graphics, 32-bit support, Steam, Proton, and gamemode.
    nixosModules.default = { config, pkgs, lib, primaryUser, ... }:
    let cfg = config.services.gaming or {}; in {
      imports = (importDir ./system);

      options.services.gaming = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable gaming support (Steam, Proton, graphics, 32-bit libraries).";
        };
        enable32bit = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable 32-bit library support for Steam games.";
        };
      };

      config = lib.mkIf cfg.enable {
        home-manager.users.${primaryUser} = {
          imports = [ self.homeManagerModules.default ];
          homeManager.gaming.enable = true;
        };
      };
    };

    # ── Home-manager module ────────────────────────────────────────────────
    # User-level Steam configuration.
    homeManagerModules.default = { config, pkgs, lib, ... }:
    let hmCfg = config.homeManager.gaming or {}; in {
      imports = (importDir ./home);

      options.homeManager.gaming = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable home-manager gaming configuration.";
        };
      };

      config = lib.mkIf hmCfg.enable {
        # Config provided by home/ fragments
      };
    };
  };
}
