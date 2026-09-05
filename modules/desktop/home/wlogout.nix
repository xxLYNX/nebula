# Home fragment — wlogout power menu (lock / logout / suspend / reboot / shutdown).
# Imported by modules/desktop/flake.nix homeManagerModules.default.
{ config, pkgs, lib, ... }:
let
  theme = import ../themes/nebula/colors.nix;
  hmCfg = config.homeManager.desktop or {};
  icons = "${pkgs.wlogout}/share/wlogout/icons";
  # GTK resolves url() relative to the stylesheet (~/.config/wlogout/style.css).
  icon = name: "image(url(\"icons/${name}.png\"), url(\"${icons}/${name}.png\"))";
in
lib.mkIf (hmCfg.enable or false) {
  # Ship icon PNGs beside style.css — bare store paths in CSS are unreliable in GTK.
  xdg.configFile."wlogout/icons".source = "${pkgs.wlogout}/share/wlogout/icons";

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
      * {
        background-image: none;
        box-shadow: none;
      }

      window {
        background-color: #${theme.backgroundAlpha};
      }

      button {
        color: #${theme.textAlpha};
        background-color: #${theme.surface};
        border: 1px solid #${theme.borderAlpha};
        border-radius: 12px;
        margin: 8px;
        padding: 32px 24px 16px 24px;
        background-repeat: no-repeat;
        background-position: center 30%;
        background-size: 28%;
      }

      button:focus,
      button:active,
      button:hover {
        background-color: #${theme.selectionAlpha};
        color: #${theme.accentAlpha};
        border-color: #${theme.accentAlpha};
        outline-style: none;
      }

      #lock     { background-image: ${icon "lock"}; }
      #logout   { background-image: ${icon "logout"}; }
      #suspend  { background-image: ${icon "suspend"}; }
      #reboot   { background-image: ${icon "reboot"}; }
      #shutdown { background-image: ${icon "shutdown"}; }
    '';
  };
}
