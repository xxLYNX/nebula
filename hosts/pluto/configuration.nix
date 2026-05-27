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
    obsidian
    zed-editor
    mage
    cargo
    rustc
    gcc
    gnumake
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

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

  # Use latest stable kernel for security updates and performance improvements
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Gaming support: Steam + Intel Iris Xe graphics + Proton + 32-bit multilib
  # Intel P-State active mode (default): uses HWP for efficient power management
  # In active mode, "powersave" governor ≈ schedutil (smart scaling)
  # GameMode will automatically boost to "performance" when games launch
  services.gaming = {
    enable = true;
    enable32bit = true;
    cpuGovernor = "powersave"; # In intel_pstate active mode, powersave = smart scaling
  };

}
