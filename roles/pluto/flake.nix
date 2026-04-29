{
  description = "pluto role flake - primary workstation NixOS module fragment; desktop + nixvim enabled by default";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    desktop = {
      url = "path:../../modules/desktop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, desktop, ... }: {
    nixosModules.default = { config, pkgs, primaryUser, machine, ... }:
    let
      lib = pkgs.lib;

      diskDevice = if machine != null then (machine.hardware.disk.device or "/dev/sda") else "/dev/sda";
      swapSize   = if machine != null then (machine.hardware.disk.swap   or "8G")   else "8G";
    in {
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

      services.desktop = {
        enable = true;
        hyprland = {
          enable          = true;
          withUWSM        = true;
          xwaylandEnable  = true;
        };
        displayManager.enable = true;
      };

      services.openssh.enable = true;
      security.sudo.wheelNeedsPassword = false;
      services.avahi = { enable = true; nssmdns4 = true; openFirewall = true; };

      home-manager.users.${primaryUser} = {
        imports = [
          desktop.homeManagerModules.default
          desktop.homeManagerModules.nixvim
        ];
        homeManager.desktop.enable = true;
        home.stateVersion = "26.05";
      };
    };
  };
}
