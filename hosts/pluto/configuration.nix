{ client, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  environment.systemPackages = with pkgs; [
    fzf
    yazi
    tree
    bitwarden-desktop
    pkgs.qbittorrent
  ];

  services.syncthing = {
    enable = true;

    # Run it as your normal user (recommended for a desktop/dev machine)
    user = "voyager";
    group = "users";

    # Where to store config + data (change if you want)
    configDir = "/home/voyager/.config/syncthing";
    dataDir = "/home/voyager/Sync"; # or wherever you want your synced folders

    # Allow you to change devices/folders from the web GUI
    overrideDevices = true;
    overrideFolders = true;

    # (Optional but nice) open the GUI only on localhost
    guiAddress = "127.0.0.1:8384";
  };

}
