{
  description = "Testing role flake - generic NixOS module fragment for test/dev machines; includes the desktop module by default and accepts a `desktop` arg to customize behavior";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Import the reusable desktop module from the repository's modules directory.
    # Relative path from `roles/testing` -> `modules/desktop` is ../../modules/desktop
    desktop = {
      url = "path:../../modules/desktop";
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
            # swap must come before root so root can safely use 100% of remaining space
            swap = {
              size = swapSize;
              content = { type = "swap"; };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/";
              };
            };
          };
        };
      };

      # Primary user
      users.users.${primaryUser} = {
        isNormalUser = true;
        extraGroups = [ "wheel" "networkmanager" ];
        # Plaintext password for testing role only. Always enforced on rebuild.
        # Replace with sops-encrypted hashedPasswordFile for production use.
        password = "changeme";
      };

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

      # Allow unfree firmware (required by hardware.enableAllFirmware in desktop module)
      nixpkgs.config.allowUnfree = true;

      # Enable flakes and the new nix CLI globally so no --extra-experimental-features flag is needed.
      # Additional settings mitigate the Nix interrupted-download store corruption bug (known since 2021):
      # stalled-download-timeout aborts stalled transfers before partial data is committed;
      # connect-timeout prevents hangs on unreachable substituters;
      # download-attempts retries transient failures automatically.
      nix.settings = {
        experimental-features   = [ "nix-command" "flakes" ];
        http-connections        = 50;
        stalled-download-timeout = 90;
        connect-timeout         = 5;
        download-attempts       = 5;
        # Colmena binary cache — set in system config so the daemon trusts it without
        # needing trusted-users. Avoids recompiling colmena from source on future applies.
        substituters            = [ "https://cache.nixos.org" "https://colmena.cachix.org" ];
        trusted-public-keys     = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "colmena.cachix.org-1:7BzpDnjjH8ki2CT3f6GdOk7QAzPOl+1t3LvTLXqYcSg="
        ];
      };

      # Automatically collect old generations weekly; never keep more than 30 days worth.
      # Combined with configurationLimit = 30 this keeps the store and /boot entries bounded.
      nix.gc = {
        automatic = true;
        dates     = "weekly";
        options   = "--delete-older-than 30d";
      };

      # Minimal packages for testing/dev machines.
      # colmena is pinned via mkHost in the root flake (matches flake input version).
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
        imports = [ desktop.homeManagerModules.default ];
        homeManager.desktop.enable = true;
        # stateVersion for home-manager must match the NixOS release in use.
        home.stateVersion = "26.05";
      };
    };
  };
}
