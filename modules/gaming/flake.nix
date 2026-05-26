{
  description = "Gaming module: Steam + Intel graphics + Proton + 32-bit support";

  inputs = {
    nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... }:
  let
    lib = nixpkgs.lib;

    importDir = dir:
      builtins.map (name: dir + "/${name}")
        (builtins.filter (name: builtins.match ".*\.nix$" name != null)
          (builtins.attrNames
            (lib.filterAttrs (_: type: type == "regular") (builtins.readDir dir))));
  in {

    # ── System NixOS module ────────────────────────────────────────────────
    # Configures: graphics drivers, 32-bit support, Steam, Proton.
    # All configuration is system-level; Steam doesn't require home-manager.
    nixosModules.default = { config, pkgs, lib, ... }:
    let cfg = config.services.gaming or {}; in {
      imports = importDir ./system;

      options.services.gaming = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable gaming support (Steam, Proton, graphics drivers, 32-bit libraries).";
        };
        enable32bit = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable 32-bit library support for Steam games.";
        };
      };
    };
  };
}
