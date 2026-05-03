{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.homeManager.desktop or { };
in
lib.mkIf (cfg.enable or false) {
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "auto";
    settings = { };
  };
}
