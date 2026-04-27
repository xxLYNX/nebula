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

          theme = {
            enable = lib.mkOption {
              type    = lib.types.bool;
              default = true;
              description = "Apply the desktop theme (GTK, Qt, cursor, dark mode). Disable to manage theming yourself.";
            };
            name = lib.mkOption {
              type    = lib.types.str;
              default = "adwaita-dark";
              description = "Theme variant to apply. Currently only adwaita-dark is bundled.";
            };
            cursor = {
              package = lib.mkOption {
                type    = lib.types.package;
                default = pkgs.bibata-cursors;
                description = "Cursor theme package.";
              };
              name = lib.mkOption {
                type    = lib.types.str;
                default = "Bibata-Modern-Classic";
                description = "Cursor theme name.";
              };
              size = lib.mkOption {
                type    = lib.types.int;
                default = 24;
                description = "Cursor size in pixels.";
              };
            };
          };
        };
      };

      config = lib.mkIf cfg.enable {
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

        # Autostart helper: only created when the autostart list is non-empty.
        # Many users prefer putting autostarts into hyprland.conf; this is an optional helper.
        systemd.user.services."desktop-autostart" = lib.mkIf (cfg.autostart != []) {
          description = "Desktop autostart helper (runs configured autostart commands)";
          wantedBy = [ "default.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.writeShellScript "desktop-autostart" (lib.concatStringsSep "\n" cfg.autostart)}";
            RemainAfterExit = "no";
          };
        };

        # Qt theming (system-level — affects all Qt apps fleet-wide)
        qt = lib.mkIf (cfg.theme.enable or true) {
          enable = true;
          platformTheme = "gnome";
          style = "adwaita-dark";
        };

        # Theme packages needed at the system level
        environment.systemPackages = lib.mkIf (cfg.theme.enable or true)
          (lib.lists.unique ([
            pkgs.adwaita-qt
            pkgs.adwaita-qt6
            pkgs.gnome-themes-extra
            pkgs.adwaita-icon-theme
            (cfg.theme.cursor.package or pkgs.bibata-cursors)
          ] ++ lib.lists.unique (cfg.packages or defaultPackages)));

        # Helpful defaults
        security.sudo.wheelNeedsPassword = lib.mkDefault true;

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
      themeCfg = hmCfg.theme or {};
      hyprSource = if (hmCfg.hyprConfigSource or null) != null
                   then hmCfg.hyprConfigSource
                   else bundledHypr;
      cursorPkg  = themeCfg.cursor.package or pkgs.bibata-cursors;
      cursorName = themeCfg.cursor.name    or "Bibata-Modern-Classic";
      cursorSize = themeCfg.cursor.size    or 24;
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
        theme = {
          enable = lib.mkOption {
            type    = lib.types.bool;
            default = true;
            description = "Apply GTK theme, cursor, dconf dark mode, and Hyprland cursor env vars.";
          };
          cursor = {
            package = lib.mkOption {
              type    = lib.types.package;
              default = pkgs.bibata-cursors;
              description = "Cursor theme package.";
            };
            name = lib.mkOption {
              type    = lib.types.str;
              default = "Bibata-Modern-Classic";
              description = "Cursor theme name (must match a theme inside cursor.package).";
            };
            size = lib.mkOption {
              type    = lib.types.int;
              default = 24;
              description = "Cursor size in pixels.";
            };
          };
        };
      };

      config = lib.mkIf (hmCfg.enable or false) {
        home.file.".config/hypr/hyprland.conf" = {
          source = hyprSource;
          # force = true so home-manager replaces any pre-existing file (e.g. the
          # auto-generated hyprland.conf from the first Hyprland launch). Without this
          # hm-activate fails with "Existing file would be clobbered".
          force = true;
        };
        home.packages = lib.lists.unique
          ((hmCfg.extraHomePackages or []) ++ [ pkgs.dunst pkgs.wl-clipboard ]);
        programs.fuzzel.enable = lib.mkDefault true;

        # ── Theming ───────────────────────────────────────────────────────────
        # All theme config is home-manager-level so it writes to user dotfiles
        # and env vars rather than system-wide paths.
        gtk = lib.mkIf (themeCfg.enable or true) {
          enable = true;
          theme = {
            name    = "Adwaita-dark";
            package = pkgs.gnome-themes-extra;
          };
          iconTheme = {
            name    = "Adwaita";
            package = pkgs.adwaita-icon-theme;
          };
          cursorTheme = {
            name    = cursorName;
            package = cursorPkg;
            size    = cursorSize;
          };
        };

        # dconf sets the system-wide GNOME/GTK color-scheme preference.
        # Apps that respect XDG color-scheme (Firefox, GTK4 apps, etc.) go dark.
        dconf = lib.mkIf (themeCfg.enable or true) {
          enable = true;
          settings."org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            gtk-theme    = "Adwaita-dark";
            icon-theme   = "Adwaita";
            cursor-theme = cursorName;
            cursor-size  = cursorSize;
          };
        };

        # Cursor for Wayland/X11 and Hyprland specifically.
        home.pointerCursor = lib.mkIf (themeCfg.enable or true) {
          gtk.enable = true;
          package    = cursorPkg;
          name       = cursorName;
          size       = cursorSize;
        };

        # Session env vars — Hyprland reads HYPRCURSOR_* to set cursor in the compositor.
        home.sessionVariables = lib.mkIf (themeCfg.enable or true) {
          XCURSOR_THEME    = cursorName;
          XCURSOR_SIZE     = builtins.toString cursorSize;
          HYPRCURSOR_THEME = cursorName;
          HYPRCURSOR_SIZE  = builtins.toString cursorSize;
        };
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
