# Gaming Steam configuration for NixOS.
# Provides: Steam client, Proton support (via Steam), input device access.
# Imported by modules/gaming/flake.nix nixosModules.default.

{ config, pkgs, lib, ... }:
let
  cfg = config.services.gaming or {};
in
lib.mkIf cfg.enable {
  # Steam client automatically includes Proton for game compatibility
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = false;
    dedicatedServer.openFirewall = false;
    protontricks.enable = true;
  };

  # Additional gaming utilities
  environment.systemPackages = with pkgs; [
    protontricks  # Tools to manage Proton installations and game configurations
  ];

  # Input device access for controllers and peripherals
  services.udev.packages = with pkgs; [
    steam-devices
  ];
}
