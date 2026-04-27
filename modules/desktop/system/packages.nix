# Desktop system fragment — system packages.
# Imported by modules/desktop/flake.nix nixosModules.default.
# Options are defined in flake.nix; this file only provides config.
{ config, pkgs, lib, ... }:
let
  cfg = config.services.desktop or {};
in
lib.mkIf (cfg.enable or false) {
  environment.systemPackages = lib.lists.unique cfg.packages;
}
