# Nebula theme — home-manager fragment.
# Applies GTK theme, cursor, dconf colour-scheme, and Hyprland cursor env vars.
# Imported by modules/desktop/flake.nix homeManagerModules.default.
{ config, pkgs, lib, ... }:
let
  theme  = import ./colors.nix;
  hmCfg  = config.homeManager.desktop or {};
  cursor = pkgs.bibata-cursors;
in
lib.mkIf ((hmCfg.enable or false) && (hmCfg.theme.enable or true)) {

  gtk = {
    enable = true;
    theme = {
      name    = theme.gtkThemeName;
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name    = theme.iconTheme;
      package = pkgs.adwaita-icon-theme;
    };
    cursorTheme = {
      name    = theme.cursorName;
      package = cursor;
      size    = theme.cursorSize;
    };
  };

  # dconf sets the GNOME/GTK color-scheme preference — read by Firefox, GTK4 apps, etc.
  dconf = {
    enable = true;
    settings."org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme    = theme.gtkThemeName;
      icon-theme   = theme.iconTheme;
      cursor-theme = theme.cursorName;
      cursor-size  = theme.cursorSize;
    };
  };

  # Wayland/X11 cursor (also picked up by Hyprland via HYPRCURSOR_*)
  home.pointerCursor = {
    gtk.enable = true;
    package    = cursor;
    name       = theme.cursorName;
    size       = theme.cursorSize;
  };

  # Session variables — Hyprland reads HYPRCURSOR_* for the compositor cursor.
  # GTK_THEME forces GTK apps to the dark variant even if dconf is not yet read.
  home.sessionVariables = {
    GTK_THEME        = theme.gtkThemeEnv;
    XCURSOR_THEME    = theme.cursorName;
    XCURSOR_SIZE     = builtins.toString theme.cursorSize;
    HYPRCURSOR_THEME = theme.cursorName;
    HYPRCURSOR_SIZE  = builtins.toString theme.cursorSize;
  };
}
