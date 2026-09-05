# Shared role baseline: disko layout, boot generations, avahi, home-manager stateVersion.
# Imported by role flakes (testing, pluto) — not a separate flake input.
{
  config,
  pkgs,
  lib,
  primaryUser,
  machine,
  ...
}:
let
  diskDevice = machine.hardware.disk.device;
  swapSize = machine.hardware.disk.swap or "8G";
  rootFormat = machine.hardware.disk.format or "xfs";
in
{
  disko.devices.disk.main = {
    type = "disk";
    device = diskDevice;
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };
        swap = {
          size = swapSize;
          content = {
            type = "swap";
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = rootFormat;
            mountpoint = "/";
          };
        };
      };
    };
  };

  system.stateVersion = "26.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 30;
  boot.loader.timeout = 5;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  home-manager.users.${primaryUser} = {
    home.stateVersion = "26.05";
  };
}
