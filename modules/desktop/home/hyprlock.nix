# Home fragment — Hyprlock screen locker (Super+L and wlogout lock button).
# Imported by modules/desktop/flake.nix homeManagerModules.default.
{ config, pkgs, lib, ... }:
let
  hmCfg = config.homeManager.desktop or {};
in
lib.mkIf (hmCfg.enable or false) {
  programs.hyprlock.enable = true;
}
