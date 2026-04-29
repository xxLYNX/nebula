# Desktop system fragment — Hyprland, portals, display manager, audio, networking.
# Imported by modules/desktop/flake.nix nixosModules.default.
# Options are defined in flake.nix; this file only provides config.
{ config, pkgs, lib, ... }:
let
  cfg = config.services.desktop or {};
in
lib.mkIf (cfg.enable or false) {

  programs.hyprland = lib.mkIf (cfg.hyprland.enable or true) {
    enable       = true;
    withUWSM     = cfg.hyprland.withUWSM or true;
    xwayland.enable = cfg.hyprland.xwaylandEnable or true;
  };

  xdg.portal = {
    enable       = true;
    extraPortals = cfg.xdg_portals or [ pkgs.xdg-desktop-portal-hyprland ];
  };

  services.displayManager.sddm.enable =
    (cfg.displayManager.enable or true) && (cfg.displayManager.manager or "sddm") == "sddm";
  services.displayManager.sddm.wayland.enable = cfg.displayManager.waylandEnable or true;

  services.pipewire = {
    enable       = true;
    alsa.enable  = true;
    pulse.enable = true;
  };

  networking.networkmanager.enable = true;
  hardware.enableAllFirmware       = true;

  services.udisks2.enable = true;
  services.gvfs.enable    = true;

  security.sudo.wheelNeedsPassword = lib.mkDefault true;

  # Enable Wayland mode for Electron/Chromium apps (Ozone) and Firefox.
  environment.sessionVariables = {
    NIXOS_OZONE_WL     = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # Optional autostart helper — only created when the list is non-empty.
  # Most users prefer exec-once in hyprland.conf instead.
  systemd.user.services."desktop-autostart" = lib.mkIf (cfg.autostart != []) {
    description = "Desktop autostart helper";
    wantedBy    = [ "default.target" ];
    serviceConfig = {
      Type            = "oneshot";
      ExecStart       = "${pkgs.writeShellScript "desktop-autostart"
                          (lib.concatStringsSep "\n" cfg.autostart)}";
      RemainAfterExit = "no";
    };
  };
}
