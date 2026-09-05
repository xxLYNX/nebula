# Home fragment — wlogout power menu (lock / logout / suspend / reboot / shutdown).
# Imported by modules/desktop/flake.nix homeManagerModules.default.
{ config, pkgs, lib, ... }:
let
  theme = import ../themes/nebula/colors.nix;
  hmCfg = config.homeManager.desktop or {};
in
lib.mkIf (hmCfg.enable or false) {
  programs.wlogout = {
    enable = true;
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
    style = ''
      window {
        background-color: #${theme.backgroundAlpha};
        font-family: sans-serif;
        font-size: 14px;
      }

      button {
        color: #${theme.textAlpha};
        background-color: #${theme.surface};
        border: 2px solid #${theme.borderAlpha};
        border-radius: 12px;
        margin: 8px;
        padding: 24px;
      }

      button:focus,
      button:hover {
        background-color: #${theme.selectionAlpha};
        color: #${theme.accentAlpha};
        border-color: #${theme.accentAlpha};
      }

      #lock { background-image: url("lock"); }
      #logout { background-image: url("logout"); }
      #suspend { background-image: url("suspend"); }
      #reboot { background-image: url("reboot"); }
      #shutdown { background-image: url("shutdown"); }
    '';
  };
}
