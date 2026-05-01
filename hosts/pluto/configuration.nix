{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  environment.systemPackages = with pkgs; [
    fzf
    yazi
    tree
    bitwarden-desktop
  ];

}
