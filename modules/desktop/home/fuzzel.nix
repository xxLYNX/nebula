# Home fragment — Fuzzel launcher.
# Configures programs.fuzzel with the nebula colour palette.
# Imported by modules/desktop/flake.nix homeManagerModules.default.
{ config, pkgs, lib, ... }:
let
  theme = import ../themes/nebula/colors.nix;
  hmCfg = config.homeManager.desktop or {};
in
lib.mkIf (hmCfg.enable or false) {
  programs.fuzzel = {
    enable   = true;
    settings = {
      main.terminal = "kitty";
      colors = {
        background        = theme.backgroundAlpha;
        text              = theme.textAlpha;
        match             = theme.accentAlpha;
        selection         = theme.selectionAlpha;
        "selection-text"  = theme.textAlpha;
        "selection-match" = theme.accentAlpha;
        border            = theme.borderAlpha;
      };
      border = { width = 2; radius = 8; };
    };
  };
}
