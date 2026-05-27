{
  description = "Gaming module: Steam + Intel graphics + Proton + 32-bit support + performance optimizations";

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
    # Configures: graphics drivers, 32-bit support, Steam, Proton, CPU frequency scaling, gamemode.
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
        cpuGovernor = lib.mkOption {
          type = lib.types.str;
          default = "schedutil";
          description = ''
            CPU frequency governor for system-wide use.
            When GameMode is enabled, it will automatically boost to "performance" during gaming.
            Options: "performance" (always max frequency), "schedutil" (intelligent scaling - recommended), "powersave" (low power).
            Default "schedutil" provides good battery life normally, with automatic performance boost during gaming.
          '';
        };
        enableGameMode = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Enable Feral GameMode for automatic performance optimizations when games launch.
            Temporarily boosts CPU governor and applies GPU optimizations during gameplay.
          '';
        };
        enablePerformanceKernelParams = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable performance-oriented kernel parameters (e.g., preempt=full for lower latency).
            May slightly reduce security for better gaming performance.
          '';
        };
      };


    };
  };
}
