{
  description = "Testing role flake - generic NixOS module fragment for test/dev machines";

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
            # swap must come before root so root can safely use 100% of remaining space
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
      # After enrollment: switch to sops-encrypted hash. See roles/pluto/flake.nix for details.
      sops.secrets = lib.optionalAttrs machineEnrolled {
        user_password_hash = { neededForUsers = true; };
      };

      # Primary user
      users.users.${primaryUser} = {
        isNormalUser = true;
        extraGroups  = [ "wheel" "networkmanager" ];
      } // (if machineEnrolled then {
        hashedPasswordFile = config.sops.secrets.user_password_hash.path;
      } else {
        password = "changeme";
      });

      # Pin to the NixOS release that was active when this host was first installed.
      # Changing this after the fact can break stateful NixOS options.
      system.stateVersion = "26.05";

      # Bootloader (systemd-boot for UEFI; disko creates the EFI partition at /boot)
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      # Show up to 30 generations in the boot menu so you can roll back if needed.
      boot.loader.systemd-boot.configurationLimit = 30;
      # Show the generation menu for 5 s on boot so you can roll back if needed.
      # Without this systemd-boot boots the latest generation immediately (timeout = 0).
      boot.loader.timeout = 5;

      # nixpkgs.config.allowUnfree, nix.settings, nix.gc, and the git/curl
      # systemPackages are provided by the universal module (modules/universal/).

      # SSH daemon — needed for remote `colmena apply`. Not required for apply-local.
      # To enable passwordless remote deployment add your SSH public key via:
      #   users.users.${primaryUser}.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];
      services.openssh.enable = true;

      # Passwordless sudo for wheel members — lets colmena escalate without prompts.
      # Acceptable on a test/dev machine; harden for production roles.
      security.sudo.wheelNeedsPassword = false;

      # Avahi/mDNS — resolves bare hostnames (e.g. "testbed") on the LAN so colmena
      # can reach this machine by name rather than requiring a hardcoded IP.
      services.avahi = { enable = true; nssmdns4 = true; openFirewall = true; };

      # Wire the desktop home-manager module for the primary user so that
      # ~/.config/hypr/hyprland.conf is managed from the repo rather than
      # falling back to Hyprland's auto-generated default config.
      home-manager.users.${primaryUser} = {
        # stateVersion for home-manager must match the NixOS release in use.
        home.stateVersion = "26.05";
      };
    };
  };
}
