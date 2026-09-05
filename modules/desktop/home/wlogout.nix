# Home fragment — wlogout power menu (lock / logout / suspend / reboot / shutdown).
# Imported by modules/desktop/flake.nix homeManagerModules.default.
{ config, pkgs, lib, ... }:
let
  theme = import ../themes/nebula/colors.nix;
  hmCfg = config.homeManager.desktop or {};
  icons = "${pkgs.wlogout}/share/wlogout/icons";
  # GTK3 CSS accepts #RRGGBB or rgba(), not #RRGGBBAA used elsewhere in the theme.
  wlogoutStyle = pkgs.writeText "wlogout-style.css" ''
    * {
      background-image: none;
      box-shadow: none;
    }

    window {
      background-color: rgba(0, 0, 0, 0.94);
    }

    button {
      color: #${theme.text};
      background-color: #${theme.surface};
      border-style: solid;
      border-width: 1px;
      border-color: rgba(51, 204, 255, 0.93);
      border-radius: 12px;
      margin: 8px;
      background-repeat: no-repeat;
      background-position: center;
      background-size: 25%;
    }

    button:focus,
    button:active,
    button:hover {
      background-color: rgba(69, 71, 90, 1);
      color: #${theme.accent};
      border-color: #${theme.accent};
      outline-style: none;
    }

    #lock {
      background-image: image(url("${icons}/lock.png"));
    }

    #logout {
      background-image: image(url("${icons}/logout.png"));
    }

    #suspend {
      background-image: image(url("${icons}/suspend.png"));
    }

    #reboot {
      background-image: image(url("${icons}/reboot.png"));
    }

    #shutdown {
      background-image: image(url("${icons}/shutdown.png"));
    }
  '';
  # wlogout defaults to 3 buttons per row; with 5 actions that creates a broken 6th
  # tile and GTK errors. Force one row and set pixbuf env for GTK image loading on NixOS.
  wlogoutWrapped = pkgs.symlinkJoin {
    name = "wlogout-wrapped";
    paths = [ pkgs.wlogout ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/wlogout \
        --add-flags "-p layer-shell" \
        --add-flags "-b 5" \
        --set GDK_PIXBUF_MODULE_FILE ${pkgs.gdk-pixbuf}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache
    '';
  };
in
lib.mkIf (hmCfg.enable or false) {
  xdg.configFile."wlogout/style.css".source = wlogoutStyle;

  programs.wlogout = {
    enable = true;
    package = wlogoutWrapped;
    layout = [
      {
        label   = "lock";
        action  = "${lib.getExe pkgs.hyprlock}";
        text    = "Lock";
        keybind = "l";
      }
      {
        label   = "logout";
        action  = "uwsm stop";
        text    = "Log out";
        keybind = "e";
      }
      {
        label   = "suspend";
        action  = "systemctl suspend";
        text    = "Suspend";
        keybind = "u";
      }
      {
        label   = "reboot";
        action  = "systemctl reboot";
        text    = "Reboot";
        keybind = "r";
      }
      {
        label   = "shutdown";
        action  = "systemctl poweroff";
        text    = "Shutdown";
        keybind = "s";
      }
    ];
  };
}
