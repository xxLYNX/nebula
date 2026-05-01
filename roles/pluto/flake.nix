{
  description = "pluto role flake - primary workstation NixOS module fragment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosModules.default = { config, pkgs, primaryUser, machine, ... }:
    let
      diskDevice = if machine != null then (machine.hardware.disk.device or "/dev/sda") else "/dev/sda";
      swapSize   = if machine != null then (machine.hardware.disk.swap   or "8G")   else "8G";
      rootFormat = if machine != null then (machine.hardware.disk.format or "xfs")  else "xfs";
    in {
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
            swap = {
              size = swapSize;
              content = { type = "swap"; };
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

      # Decrypt the user's hashed password from the machine's sops secrets file.
      # The secret must exist (run scripts/enroll-machine.sh) before the first apply
      # that includes this role, or sops-nix activation will fail with a missing-key error.
      # neededForUsers = true ensures decryption happens before the users module runs.
      sops.secrets.user_password_hash = {
        neededForUsers = true;
      };

      users.users.${primaryUser} = {
        isNormalUser      = true;
        extraGroups       = [ "wheel" "networkmanager" ];
        hashedPasswordFile = config.sops.secrets.user_password_hash.path;
      };

      system.stateVersion = "26.05";

      boot.loader.systemd-boot.enable      = true;
      boot.loader.efi.canTouchEfiVariables  = true;
      boot.loader.systemd-boot.configurationLimit = 30;
      boot.loader.timeout = 5;

      # nixpkgs.config.allowUnfree, nix.settings, nix.gc, and the git/curl
      # systemPackages are provided by the universal module (modules/universal/).

      services.openssh.enable = false;
      security.sudo.wheelNeedsPassword = true;
      services.avahi = { enable = true; nssmdns4 = true; openFirewall = true; };

      home-manager.users.${primaryUser} = {
        home.stateVersion = "26.05";
      };
    };
  };
}
