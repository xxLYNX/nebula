# Nebula theme — system-level NixOS fragment.
# Provides Qt theming and the system packages needed for GTK/cursor themes.
# Imported by modules/desktop/flake.nix nixosModules.default.
{ config, pkgs, lib, ... }:
let
  cfg = config.services.desktop or {};
in
lib.mkIf (cfg.enable or false) {
  # Qt theming (system-level — affects all Qt apps)
  qt = {
    enable        = true;
    platformTheme = "gnome";
    style         = "adwaita-dark";
  };

  # Packages required to apply the nebula (Adwaita-dark + Bibata) theme system-wide.
  environment.systemPackages = [
    pkgs.adwaita-qt
    pkgs.adwaita-qt6
    pkgs.gnome-themes-extra
    pkgs.adwaita-icon-theme
    pkgs.bibata-cursors
  ];
}
