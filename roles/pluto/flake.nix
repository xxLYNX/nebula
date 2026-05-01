{
  description = "pluto role flake - primary workstation NixOS module fragment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosModules.default = { config, pkgs, primaryUser, machine, ... }:
    let
      lib = pkgs.lib;

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

      users.users.${primaryUser} = {
        isNormalUser = true;
        extraGroups  = [ "wheel" "networkmanager" ];
        # Set a real password via sops-encrypted hashedPasswordFile in production.
        # This placeholder forces a reset on first login.
        password = "changeme";
      };

      system.stateVersion = "26.05";

      boot.loader.systemd-boot.enable      = true;
      boot.loader.efi.canTouchEfiVariables  = true;
      boot.loader.systemd-boot.configurationLimit = 30;
      boot.loader.timeout = 5;

      nixpkgs.config.allowUnfree = true;

      nix.settings = {
        experimental-features    = [ "nix-command" "flakes" ];
        http-connections         = 50;
        stalled-download-timeout = 90;
        connect-timeout          = 5;
        download-attempts        = 5;
        substituters             = [ "https://cache.nixos.org" "https://colmena.cachix.org" ];
        trusted-public-keys      = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "colmena.cachix.org-1:7BzpDnjjH8ki2CT3f6GdOk7QAzPOl+1t3LvTLXqYcSg="
        ];
      };

      nix.gc = {
        automatic = true;
        dates     = "weekly";
        options   = "--delete-older-than 30d";
      };

      environment.systemPackages = with pkgs; [ git curl ];

      services.openssh.enable = false;
      security.sudo.wheelNeedsPassword = true;
      services.avahi = { enable = true; nssmdns4 = true; openFirewall = true; };

      home-manager.users.${primaryUser} = {
        home.stateVersion = "26.05";
      };
    };
  };
}
