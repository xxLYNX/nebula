{
  description = "Composable desktop module: Hyprland + desktop helpers (system + home-manager fragments)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, nixvim, ... }:
  let
    pkgs = import nixpkgs { system = "x86_64-linux"; };
    lib  = pkgs.lib;
    defaultPackages = with pkgs; [
      hyprland xdg-desktop-portal-hyprland
      kitty dunst wl-clipboard fuzzel wev mpv
    ];
  in {

    # ── System NixOS module ────────────────────────────────────────────────
    # Composes: Hyprland/portals/audio/networking, system packages, nebula Qt theme.
    # All config lives in system/ and themes/nebula/system.nix; options live here.
    nixosModules.default = { config, pkgs, lib, ... }:
    let cfg = config.services.desktop or {}; in {
      imports = [
        ./system/hyprland.nix
        ./system/packages.nix
        ./themes/nebula/system.nix
      ];

      options.services.desktop = {
        enable = lib.mkOption {
          type    = lib.types.bool;
          default = false;
          description = "Master switch for the desktop module.";
        };
        packages = lib.mkOption {
          type    = lib.types.listOf lib.types.package;
          default = defaultPackages;
          description = "System packages to install for the desktop role.";
        };
        hyprland = {
          enable = lib.mkOption {
            type    = lib.types.bool;
            default = true;
            description = "Enable Hyprland compositor.";
          };
          withUWSM = lib.mkOption {
            type    = lib.types.bool;
            default = true;
            description = "Enable UWSM integration (recommended on recent NixOS).";
          };
          xwaylandEnable = lib.mkOption {
            type    = lib.types.bool;
            default = true;
            description = "Enable XWayland for X11 app compatibility.";
          };
        };
        xdg_portals = lib.mkOption {
          type    = lib.types.listOf lib.types.package;
          default = [ pkgs.xdg-desktop-portal-hyprland ];
          description = "XDG portal packages for screen sharing/file pickers.";
        };
        displayManager = {
          enable = lib.mkOption {
            type    = lib.types.bool;
            default = true;
            description = "Enable a display manager for graphical login (SDDM by default).";
          };
          manager = lib.mkOption {
            type    = lib.types.str;
            default = "sddm";
            description = "Display manager to use (sddm, gdm, lightdm).";
          };
          waylandEnable = lib.mkOption {
            type    = lib.types.bool;
            default = true;
            description = "Enable Wayland support in the display manager.";
          };
        };
        autostart = lib.mkOption {
          type    = lib.types.listOf lib.types.str;
          default = [];
          description = "Commands to autostart via a systemd user service. Most users prefer exec-once in hyprland.conf.";
        };
        theme = {
          enable = lib.mkOption {
            type    = lib.types.bool;
            default = true;
            description = "Apply the nebula theme (Qt, GTK, cursor). Disable to manage theming yourself.";
          };
        };
      };
    };

    # ── Home-manager module ────────────────────────────────────────────────
    # Composes: hyprland.conf file, fuzzel, kitty, dunst, nebula GTK/cursor theme.
    # All config lives in home/ and themes/nebula/home.nix; options live here.
    homeManagerModules.default = { config, pkgs, lib, ... }:
    let hmCfg = config.homeManager.desktop or {}; in {
      imports = [
        ./home/hyprland.nix
        ./home/fuzzel.nix
        ./home/kitty.nix
        ./home/dunst.nix
        ./themes/nebula/home.nix
      ];

      options.homeManager.desktop = {
        enable = lib.mkOption {
          type    = lib.types.bool;
          default = false;
          description = "Enable home-manager desktop fragments (hyprland.conf, fuzzel, kitty, dunst, nebula theme).";
        };
        hyprConfigSource = lib.mkOption {
          type    = lib.types.nullOr lib.types.path;
          default = null;
          description = "Override path for ~/.config/hypr/hyprland.conf. Defaults to themes/nebula/compositor/hyprland.conf.";
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
        };
      };

      # Extra home packages (not tied to a specific app fragment)
      config = lib.mkIf (hmCfg.enable or false) {
        home.packages = hmCfg.extraHomePackages or [];
      };
    };

    # ── Nixvim editor module (opt-in by import) ────────────────────────────
    # Import this in your role's home-manager config when you want the full
    # neovim setup. Not included in homeManagerModules.default so machines
    # that don't need an editor don't pull in the closure.
    homeManagerModules.nixvim = { pkgs, ... }: {
      imports = [
        nixvim.homeModules.nixvim
        ./home/nixvim.nix
      ];
    };
  };
}
