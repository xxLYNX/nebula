# Home fragment — Kitty terminal emulator.
# Imported by modules/desktop/flake.nix homeManagerModules.default.
{ config, pkgs, lib, ... }:
let
  hmCfg = config.homeManager.desktop or {};
in
lib.mkIf (hmCfg.enable or false) {
  programs.kitty = {
    enable   = true;
    font     = { name = "monospace"; size = 12; };
    settings = {
      confirm_os_window_close    = 0;
      dynamic_background_opacity = true;
      enable_audio_bell          = false;
      # Hyprland can report a tiled window as maximized; Kitty persists that in
      # ~/.local/state/kitty and the next instance requests fullscreen/maximize.
      # See kitty#10442 and hyprwm/Hyprland#16404 — upstream fix is this opt-out.
      remember_window_size       = false;
    };
  };
}
