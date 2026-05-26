# Home-manager Steam configuration.
# Provides: Steam client user setup.
# Imported by modules/gaming/flake.nix homeManagerModules.default.

{ config, pkgs, lib, ... }:
let
  hmCfg = config.homeManager.gaming or {};
in
lib.mkIf hmCfg.enable {
  # Enable Steam for the user
  programs.steam = {
    enable = true;
  };
}
