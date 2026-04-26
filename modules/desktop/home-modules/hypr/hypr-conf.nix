{ pkgs, lib ? pkgs.lib }:

# Home-modules for Hyprland and Fuzzel
#
# This file exports two home-manager module fragments as an attrset:
# {
#   hypr = <home-manager module fragment for hyprland.conf>;
#   fuzzel = <home-manager module fragment for fuzzel user config>;
# }
#
# Usage examples:
# 1) Import the hypr fragment in a user's home.nix:
#    let hyprMods = import ./home-modules/hypr/hypr-conf.nix { inherit pkgs lib; }; in
#    {
#      imports = [ hyprMods.hypr ];
#      homeManager.desktop.hyprConfigSource = ./modules/desktop/hypr/hyprland.conf;
#      homeManager.desktop.enable = true;
#    }
#
# 2) Or include both fragments directly:
#    imports = [ (import ./home-modules/hypr/hypr-conf.nix { inherit pkgs lib; }).hypr
#                (import ./home-modules/hypr/hypr-conf.nix { inherit pkgs lib; }).fuzzel ];
#
# Relative paths:
# - The bundled hypr config shipped with the module is expected at:
#   ../../hypr/hyprland.conf  (relative to this file: modules/desktop/home-modules/hypr/)
#
let
  bundledHypr = ../../hypr/hyprland.conf;
in
{
  hypr = { config, pkgs, lib, ... }:
  let
    hmCfg = config.homeManager.desktop or {};
    hyprSource = if (hmCfg.hyprConfigSource or null) != null then hmCfg.hyprConfigSource else bundledHypr;
    extraPkgs = lib.lists.unique ((hmCfg.extraHomePackages or []) ++ [ pkgs.dunst pkgs.wl-clipboard ]);
  in
  {
    options = {
      # Options are namespaced under homeManager.desktop.* by convention used elsewhere
      homeManager.desktop = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Install hyprland.conf and desktop user helpers into the user's home.";
        };

        hyprConfigSource = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Optional path to a hyprland.conf source to install as ~/.config/hypr/hyprland.conf. If null, the module uses the bundled hyprland.conf.";
        };

        extraHomePackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [];
          description = "Additional home packages to install for the desktop user (merged with sensible defaults).";
        };
      };
    };

    config = lib.mkIf (hmCfg.enable) {
      # Write the hyprland.conf into the user's dotfiles
      home.file.".config/hypr/hyprland.conf".source = hyprSource;

      # Ensure notification + clipboard helpers are available in user env
      home.packages = extraPkgs;

      # Useful user-level helpers commonly used with Hyprland
      programs.fuzzel.enable = true;
    };
  };

  fuzzel = { config, pkgs, lib, ... }:
  let
    fzCfg = config.homeManager.fuzzel or {};
    # Default fuzzel settings inspired by legacy config
    defaultSettings = {
      main = {
        terminal = "kitty";
        # width = 600;
        # lines = 12;
      };
      colors = {
        background = "000000f0";
        text = "cdd6f4ff";
        match = "89b4faff";
        selection = "45475aff";
        "selection-text" = "cdd6f4ff";
        "selection-match" = "89b4faff";
        border = "33ccffee";
      };
      border = { width = 2; radius = 8; };
    };
    mergedSettings = lib.recursiveUpdate defaultSettings (fzCfg.settings or {});
  in
  {
    options = {
      homeManager.fuzzel = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable per-user Fuzzel settings (UI launcher) and provide a small default configuration.";
        };

        settings = lib.mkOption {
          type = lib.types.any;
          default = {};
          description = "Overrideable settings for fuzzel (merged with reasonable defaults).";
        };

        extraHomePackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [];
          description = "Additional packages to install alongside fuzzel for the user.";
        };
      };
    };

    config = lib.mkIf (fzCfg.enable) {
      home.packages = lib.lists.unique (fzCfg.extraHomePackages or []);

      # Use home-manager's native fuzzel module which produces a correctly-formatted INI config.
      programs.fuzzel = {
        enable = true;
        settings = mergedSettings;
      };
    };
  };
}
