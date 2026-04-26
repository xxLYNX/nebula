{ pkgs, lib ? pkgs.lib }:

# Desktop submodule: packages and Hyprland helper fragments
#
# Exports:
# - packages: a list of common desktop packages (suitable to include into environment.systemPackages)
# - hyprlandHomeModule: a home-manager module fragment that installs hyprland.conf and user helpers
# - hyprlandHelper: small system-level helper that can wire autostart entries into the desktop module
#
# Note: this file is evaluated from the `modules/desktop/submodules` directory. Paths to bundled
# assets (e.g. the hyprland.conf shipped in modules/desktop/hypr/) assume `../hypr/hyprland.conf`.

let
  # minimal set of packages commonly used on a Hyprland desktop
  defaultPackages = [
    pkgs.hyprland
    pkgs.xdg-desktop-portal-hyprland
    pkgs.kitty
    pkgs.dunst
    pkgs.wl-clipboard
    pkgs.fuzzel
    pkgs.wev
    pkgs.mpv
  ];

  # bundled hyprland config shipped with the module (relative to this file)
  bundledHyprConf = ./../hypr/hyprland.conf;
in
{
  # A simple list suitable for inclusion. Roles/modules can call this or directly include.
  packages = defaultPackages;

  # Home-manager fragment: expects to be included by a home-manager evaluation or via
  # the top-level NixOS evaluation that imports/uses home-manager.
  #
  # Usage:
  # - include this as a `homeManagerModules.default` fragment, or
  # - call it directly in a user's `home.nix` as an import.
  #
  # The fragment reads `homeManager.desktop.enable` and related options when present.
  hyprlandHomeModule = { config, pkgs, lib, ... }:
    let
      hmCfg = config.homeManager.desktop or {};
      # allow an override of the hypr config source; default to the bundled file
      hyprSource = if (hmCfg.hyprConfigSource or null) != null then hmCfg.hyprConfigSource else bundledHyprConf;
      extraPkgs = lib.lists.unique ((hmCfg.extraHomePackages or []) ++ [ pkgs.dunst pkgs.wl-clipboard ]);
    in
    {
      options = {
        homeManager.desktop = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Expose hyprland/home defaults and install hyprland.conf into the user's dotfiles.";
          };

          hyprConfigSource = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Optional path used as source for ~/.config/hypr/hyprland.conf. If null, uses module-bundled config.";
          };

          extraHomePackages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [];
            description = "Additional packages to install into the user's environment for desktop workflows.";
          };
        };
      };

      # Only produce config when fragment is enabled
      config = lib.mkIf (hmCfg.enable) {
        # Install hyprland.conf into the user's home
        home.file.".config/hypr/hyprland.conf".source = hyprSource;

        # Combine extra packages with useful runtime helpers
        home.packages = extraPkgs;

        # Helpful user-level programs commonly used with hyprland
        programs.fuzzel.enable = true;
      };
    };

  # Small system-level helper fragment for Hyprland-related conveniences.
  # Accepts a small argument set (enable, autostart) and returns a NixOS module fragment.
  #
  # Example use from a role/module:
  #   inherit (import ./submodules/packages.nix { inherit pkgs lib; }).hyprlandHelper;
  #   then include `hyprlandHelper { enable = true; autostart = [ "nm-applet" "waybar" ]; }` in imports.
  hyprlandHelper = { enable ? true, autostart ? [] }:
    { config, pkgs, lib, ... }:
      lib.mkIf enable {
        # Expose autostart commands to the top-level desktop module namespace
        services.desktop.autostart = autostart;

        # Provide minimal system package helpers: ensure dunst/wl-clipboard exist at system-level
        environment.systemPackages = [ pkgs.dunst pkgs.wl-clipboard ];

        # Optional: a tiny systemd user helper that runs configured autostart commands.
        # Many users still prefer putting autostarts into hyprland.conf; this is optional.
        systemd.user.services."desktop-autostart" = {
          description = "Desktop autostart helper (runs configured autostart commands)";
          wantedBy = [ "default.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.concatStringsSep " && " (map (cmd: "sh -c '${lib.escapeShellCommand cmd}'") (autostart or []));
            RemainAfterExit = "no";
          };
        };
      };
}
