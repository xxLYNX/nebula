# Nebula theme — colour palette and metadata.
# All downstream files (home/fuzzel.nix, home/dunst.nix, themes/nebula/home.nix …)
# import this file directly so colours are defined in exactly one place.
#
# Format guide:
#   *       — bare hex string, no #, no alpha (for #RRGGBB contexts: GTK env vars, dunst)
#   *Alpha  — bare RRGGBBAA string (fuzzel INI format)
#   *Hypr   — rgba() / angle string ready for Hyprland col.* variables
{
  # ── Base palette ──────────────────────────────────────────────────────────
  background     = "000000";   backgroundAlpha = "000000f0";
  surface        = "1e1e2e";   # Catppuccin Mocha base — used for notification/popup backgrounds
  text           = "cdd6f4";   textAlpha       = "cdd6f4ff";
  accent         = "89b4fa";   accentAlpha     = "89b4faff";
  selection      = "45475a";   selectionAlpha  = "45475aff";
  border         = "33ccff";   borderAlpha     = "33ccffee";
  borderInactive = "595959";   borderInactiveAlpha = "595959aa";
  shadow         = "1a1a1a";   shadowAlpha     = "1a1a1aee";

  # ── Hyprland col.* format (rgba() strings, passed verbatim) ──────────────
  activeBorderHypr   = "rgba(33ccffee) rgba(00ff99ee) 45deg";
  inactiveBorderHypr = "rgba(595959aa)";
  shadowHypr         = "rgba(1a1a1aee)";

  # ── GTK / cursor ──────────────────────────────────────────────────────────
  gtkThemeName = "Adwaita-dark";  # used in gtk.theme.name and dconf gtk-theme
  gtkThemeEnv  = "Adwaita:dark";  # GTK_THEME env var format (name:variant)
  iconTheme    = "Adwaita";
  cursorName   = "Bibata-Modern-Classic";
  cursorSize   = 24;
}
