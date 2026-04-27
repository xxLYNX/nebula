# Home fragment — Hyprland config file.
# Installs the nebula compositor hyprland.conf into ~/.config/hypr/hyprland.conf.
# Imported by modules/desktop/flake.nix homeManagerModules.default.
{ config, pkgs, lib, ... }:
let
  hmCfg     = config.homeManager.desktop or {};
  # Default to the nebula compositor config; callers can override via hyprConfigSource.
  hyprSource = if (hmCfg.hyprConfigSource or null) != null
               then hmCfg.hyprConfigSource
               else ../themes/nebula/compositor/hyprland.conf;
in
lib.mkIf (hmCfg.enable or false) {
  home.file.".config/hypr/hyprland.conf" = {
    source = hyprSource;
    # force = true replaces any pre-existing file (e.g. Hyprland's auto-generated
    # default on first launch). Without this hm-activate errors with "would clobber".
    force  = true;
  };
}
