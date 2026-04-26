{
  description = "Composable desktop module: Hyprland + desktop helpers (system + home-manager fragments)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... } @ inputs:
  let
    pkgs = import nixpkgs { system = "x86_64-linux"; };
    lib  = pkgs.lib;
    this = ./.;
  in {
    # System-level NixOS module fragment for desktop-related system configuration.
    nixosModules.default = { config, pkgs, lib, ... } @ args:
    let
      cfg = config.services.desktop or {};
      defaultPackages = with pkgs; [
        hyprland
        xdg-desktop-portal-hyprland
        kitty
        dunst
        wl-clipboard
        fuzzel
        wev
        mpv
      ];
    in {
      options = {
        services.desktop = {
          description = "Convenience module to enable and configure Hyprland-based desktop stacks.";
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Master switch for the desktop convenience module.";
          };

          packages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = defaultPackages;
            description = "List of system packages to install for the desktop role.";
          };

          hyprland = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to enable Hyprland (only meaningful when services.desktop.enable is true).";
            };
            withUWSM = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable UWSM integration (recommended on recent NixOS versions).";
            };
            xwaylandEnable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable xwayland for X11 apps compatibility.";
            };
          };

          xdg_portals = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ pkgs.xdg-desktop-portal-hyprland ];
            description = "Additional portal packages to enable for screen sharing/file pickers on Wayland.";
          };

          displayManager = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to enable a display manager for graphical login (defaults to SDDM when true).";
            };
            manager = lib.mkOption {
              type = lib.types.str;
              default = "sddm";
              description = "Preferred display manager (e.g., sddm, gdm, lightdm).";
            };
            waylandEnable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to enable Wayland support in the display manager.";
            };
          };

          autostart = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "List of commands to autostart in the Hyprland session (helper provided).";
          };

          homeManager = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Expose recommended home-manager fragments via this module (for user dotfiles)";
            };

            exposeHyprConfig = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "When true, the flake exposes a home-manager fragment to manage hyprland.conf from the repo (see homeManagerModules.default).";
            };

            hyprConfigSource = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "If set and homeManager.exposeHyprConfig is true, used as the home-manager source for ~/.config/hypr/hyprland.conf (e.g. ../hypr/hyprland.conf).";
            };
          };
        };
      };

      config = lib.mkIf cfg.enable {
        # Ensure the requested set of system packages is installed.
        environment.systemPackages = lib.lists.unique (cfg.packages or defaultPackages);

        # Hyprland wiring
        programs.hyprland = lib.mkIf (cfg.hyprland.enable or true) {
          enable = true;
          withUWSM = cfg.hyprland.withUWSM or true;
          xwayland.enable = cfg.hyprland.xwaylandEnable or true;
        };

        # XDG portals for Wayland
        xdg.portal = {
          enable = true;
          extraPortals = cfg.xdg_portals or [ pkgs.xdg-desktop-portal-hyprland ];
        };

        # Display manager (wire SDDM by default)
        services.displayManager.sddm.enable =
          (cfg.displayManager.enable or true) && (cfg.displayManager.manager or "sddm") == "sddm";
        services.displayManager.sddm.wayland.enable = cfg.displayManager.waylandEnable or true;

        # Networking and helper services for desktop use
        networking.networkmanager.enable = true;
        hardware.enableAllFirmware = true;

        # Useful desktop conveniences (udisks2, gvfs)
        services.udisks2.enable = true;
        services.gvfs.enable = true;

        # PipeWire defaults for audio (modern Wayland desktops)
        services.pipewire.enable = true;
        services.pipewire.alsa.enable = true;
        services.pipewire.pulse.enable = true;

        # Autostart helper: runs the configured commands at login as a user service.
        # Many users prefer to put autostarts into hyprland.conf; this is an optional helper.
        systemd.user.services."desktop-autostart" = {
          description = "Desktop autostart helper (runs configured autostart commands)";
          wantedBy = [ "default.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.concatStringsSep " && " (map (cmd: "sh -c '${lib.escapeShellCommand cmd}'") (cfg.autostart or []));
            RemainAfterExit = "no";
          };
        };

        # Helpful defaults
        security.sudo.wheelNeedsPassword = true;

        # Expose a small set of session variables recommended for Wayland/Hyprland
        environment.sessionVariables = {
          NIXOS_OZONE_WL = "1";
          MOZ_ENABLE_WAYLAND = "0";
        };
      };
    };

    # Home-manager module composition and exposure.
    # We wire the submodules' provided home fragments into the desktop's homeManagerModules.default
    # so that including `modules/desktop` in the NixOS evaluation also gives access to a ready-to-use user fragment.
    #
    # Additionally export a listing of `home-modules` so callers can introspect available home modules.
    homeManagerModules.default = { config, pkgs, lib, ... }:
    let
      bundledHypr = ./hypr/hyprland.conf;
      hmCfg = config.homeManager.desktop or {};
      hyprSource = if (hmCfg.hyprConfigSource or null) != null
                   then hmCfg.hyprConfigSource
                   else bundledHypr;
    in {
      options.homeManager.desktop = {
        enable = lib.mkOption {
          type    = lib.types.bool;
          default = false;
          description = "Install hyprland.conf and desktop user helpers into the user's home.";
        };
        hyprConfigSource = lib.mkOption {
          type    = lib.types.nullOr lib.types.path;
          default = null;
          description = "Source path for ~/.config/hypr/hyprland.conf. Defaults to the bundled config.";
        };
        extraHomePackages = lib.mkOption {
          type    = lib.types.listOf lib.types.package;
          default = [];
          description = "Extra packages to install in the user's home environment.";
        };
      };

      config = lib.mkIf (hmCfg.enable or false) {
        home.file.".config/hypr/hyprland.conf".source = hyprSource;
        home.packages = lib.lists.unique
          ((hmCfg.extraHomePackages or []) ++ [ pkgs.dunst pkgs.wl-clipboard ]);
        programs.fuzzel.enable = lib.mkDefault true;
      };
    };

    # For convenience, also expose a small attribute set listing available home-modules at evaluation time.
    # This can be imported by other flakes or used by tooling to discover fragment names.
    # Note: builtins.readDir returns a list of file names contained in the directory.
    homeModules = {
      available = builtins.readDir ./home-modules;
      path = ./home-modules;
    };
  };
}
