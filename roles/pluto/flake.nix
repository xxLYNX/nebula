{
  description = "pluto role flake - primary workstation NixOS module fragment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosModules.default = { config, pkgs, lib, primaryUser, machine, machineEnrolled, ... }:
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

      # Before enrollment: use bootstrap password so colmena can apply.
      # After enrollment (enroll-machine.sh committed machine.yaml): switch to the
      # sops-encrypted hash. machineEnrolled is set by mkHost in flake.nix based on
      # whether secrets/machines/<hostname>/machine.yaml exists in the flake store.
      sops.secrets = lib.optionalAttrs machineEnrolled {
        user_password_hash = { neededForUsers = true; };
      };

      users.users.${primaryUser} = {
        isNormalUser = true;
        extraGroups  = [ "wheel" "networkmanager" ];
      } // (if machineEnrolled then {
        hashedPasswordFile = config.sops.secrets.user_password_hash.path;
      } else {
        password = "changeme";
      });

      system.stateVersion = "26.05";

      boot.loader.systemd-boot.enable      = true;
      boot.loader.efi.canTouchEfiVariables  = true;
      boot.loader.systemd-boot.configurationLimit = 30;
      boot.loader.timeout = 5;

      # nixpkgs.config.allowUnfree, nix.settings, nix.gc, and the git/curl
      # systemPackages are provided by the universal module (modules/universal/).

      # openssh must be enabled so NixOS generates /etc/ssh/ssh_host_ed25519_key
      # at activation. sops-nix derives its age identity from that key, and the
      # enroll script derives this machine's SOPS recipient from its public half.
      # openFirewall defaults to false, so port 22 is not exposed externally.
      services.openssh = {
        enable = true;
        openFirewall = false;
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };
      security.sudo.wheelNeedsPassword = true;
      services.avahi = { enable = true; nssmdns4 = true; openFirewall = true; };

      home-manager.users.${primaryUser} = {
        home.stateVersion = "26.05";
      };
    };
  };
}
