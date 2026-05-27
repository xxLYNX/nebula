# Gaming Steam configuration for NixOS.
# Provides: Steam client with Proton and automatic controller/input device support.
# GameMode integration: When enabled via services.gaming.enableGameMode, Steam games
# can automatically use gamemode for performance optimizations.
# Imported by modules/gaming/flake.nix nixosModules.default.

{ config, pkgs, lib, ... }:
let
  cfg = config.services.gaming or {};
in
lib.mkIf cfg.enable {
  # Steam client automatically includes Proton for game compatibility
  # Controller/input device udev rules are included automatically
  # GameMode: To use gamemode with Steam games, right-click game in Steam library →
  # Properties → Launch Options → add: gamemoderun %command%
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = false;
    dedicatedServer.openFirewall = false;
    protontricks.enable = true;
    # GameMode is configured separately in performance.nix
    gamescopeSession.enable = false;  # Gamescope session not needed for standard desktop gaming
  };

  # Additional gaming utilities
  environment.systemPackages = with pkgs; [
    protontricks  # Tools to manage Proton installations and game configurations
  ] ++ lib.optionals cfg.enableGameMode [
    gamemode      # Makes gamemoderun command available for Steam launch options
  ];
}
