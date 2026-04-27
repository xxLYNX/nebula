# Home fragment — Dunst notification daemon.
# Configures services.dunst with the nebula colour palette.
# Imported by modules/desktop/flake.nix homeManagerModules.default.
{ config, pkgs, lib, ... }:
let
  theme = import ../themes/nebula/colors.nix;
  hmCfg = config.homeManager.desktop or {};
  surface = "#${theme.surface}";
  fg      = "#${theme.text}";
  bord    = "#${theme.border}";
  crit    = "#f38ba8";
in
lib.mkIf (hmCfg.enable or false) {
  services.dunst = {
    enable   = true;
    settings = {
      global = {
        follow       = "keyboard";
        width        = 300;
        height       = 300;
        origin       = "top-right";
        offset       = "10x10";
        transparency = 10;
        frame_color  = "#888888";
        font         = "Monospace 12";
      };
      urgency_low = {
        background  = surface;
        foreground  = fg;
        timeout     = 10;
      };
      urgency_normal = {
        background  = surface;
        foreground  = fg;
        timeout     = 10;
      };
      urgency_critical = {
        background  = crit;
        foreground  = surface;
        frame_color = crit;
        timeout     = 0;
      };
    };
  };
}
