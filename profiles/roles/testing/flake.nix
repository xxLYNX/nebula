{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs, ... }: {
    nixosModules.default = { config, pkgs, primaryUser, ... }:
    let
      inventory = builtins.fromJSON (builtins.readFile ../../../inventory/machines.json);
      machine = inventory.machines.testbed;
      diskDevice = machine.diskDevice or "/dev/sda";   # fallback for non-NVMe
    in {
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
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/";
              };
            };
            swap = {
              size = machine.swapSize or "8G";
              content = {
                type = "swap";
              };
            };
          };
        };
      };

      users.users.${primaryUser} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      };

      environment.systemPackages = with pkgs; [ git curl ];
      system.stateVersion = "25.05";
    };
  };
}
