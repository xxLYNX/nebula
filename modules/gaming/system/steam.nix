# Gaming Steam configuration for NixOS.
# Provides: Steam client, Proton support, input device access.
# Imported by modules/gaming/flake.nix nixosModules.default.

{ config, pkgs, lib, ... }:
let
  cfg = config.services.gaming or {};
in
lib.mkIf cfg.enable {
  # Steam client and Proton for running non-native games
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = false;
    dedicatedServer.openFirewall = false;
    protontricks.enable = true;
  };

  # Ensure Proton is available (latest stable version)
  environment.systemPackages = with pkgs; [
    proton-latest
    proton-ge-bin
  ];

  # Input device access for controllers and peripherals
  services.udev.packages = with pkgs; [
    # Already included by Steam, but explicit for clarity
    steam-devices
  ];
}
