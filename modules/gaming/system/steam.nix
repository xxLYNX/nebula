# Gaming Steam configuration for NixOS.
# Provides: Steam client with Proton and automatic controller/input device support.
# Imported by modules/gaming/flake.nix nixosModules.default.

{ config, pkgs, lib, ... }:
let
  cfg = config.services.gaming or {};
in
lib.mkIf cfg.enable {
  # Steam client automatically includes Proton for game compatibility
  # Controller/input device udev rules are included automatically
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
}
