# Desktop system fragment — system packages.
# Imported by modules/desktop/flake.nix nixosModules.default.
# Options are defined in flake.nix; this file only provides config.
{ config, pkgs, lib, ... }:
let
  cfg = config.services.desktop or {};
  defaultPackages = with pkgs; [
    hyprland
    xdg-desktop-portal-hyprland
    kitty
    dunst
    wl-clipboard
    fuzzel
    wev
    mpv
  ];
in
lib.mkIf (cfg.enable or false) {
  environment.systemPackages = lib.lists.unique (cfg.packages or defaultPackages);
}
