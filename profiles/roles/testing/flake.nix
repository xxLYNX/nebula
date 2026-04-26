{
  description = "Testing role flake - generic NixOS module fragment for test/dev machines; includes the desktop module by default and accepts a `desktop` arg to customize behavior";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Import the reusable desktop module from the repository's modules directory.
    # Relative path from `profiles/roles/testing` -> `modules/desktop` is ../../../modules/desktop
    desktop = {
      url = "path:../../../modules/desktop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, desktop, ... }: {
    nixosModules.default = { config, pkgs, primaryUser, machine, ... }:
    let
      lib = pkgs.lib;

      diskDevice = if machine != null then (machine.diskDevice or "/dev/sda") else "/dev/sda";
      swapSize   = if machine != null then (machine.swapSize or "8G") else "8G";
    in {
      # Pull in the desktop module as an import so NixOS evaluates it in the
      # normal module system (options/config merging) rather than calling it manually.
      imports = [ desktop.nixosModules.default ];

      # Disk partitioning via disko
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
              size = swapSize;
              content = { type = "swap"; };
            };
          };
        };
      };

      # Primary user
      users.users.${primaryUser} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      };

      # Bootloader (systemd-boot for UEFI; disko creates the EFI partition at /boot)
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;

      # Allow unfree firmware (required by hardware.enableAllFirmware in desktop module)
      nixpkgs.config.allowUnfree = true;

      # Minimal packages for testing/dev machines
      environment.systemPackages = with pkgs; [ git curl ];

      # Enable the desktop module by default for the testing role
      services.desktop = {
        enable = true;
        hyprland = {
          enable = true;
          withUWSM = true;
          xwaylandEnable = true;
        };
        displayManager.enable = true;
      };
    };
  };
}
