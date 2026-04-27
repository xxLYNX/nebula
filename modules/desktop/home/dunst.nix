# Home fragment — Dunst notification daemon.
# Configures services.dunst with the nebula colour palette.
# Imported by modules/desktop/flake.nix homeManagerModules.default.
{ config, pkgs, lib, ... }:
let
  theme = import ../themes/nebula/colors.nix;
  hmCfg = config.homeManager.desktop or {};
  bg    = "#${theme.background}";
  fg    = "#${theme.text}";
  bord  = "#${theme.border}";
in
lib.mkIf (hmCfg.enable or false) {
  services.dunst = {
    enable   = true;
    settings = {
      global = {
        follow      = "mouse";
        width       = 300;
        height      = 300;
        origin      = "top-right";
        offset      = "10x10";
        transparency = 10;
        frame_color = bord;
        font        = "monospace 10";
      };
      urgency_low = {
        background  = bg;
        foreground  = fg;
        frame_color = bord;
      };
      urgency_normal = {
        background  = bg;
        foreground  = fg;
        frame_color = bord;
      };
      urgency_critical = {
        background  = bg;
        foreground  = "#ff5555";
        frame_color = "#ff5555";
      };
    };
  };
}
