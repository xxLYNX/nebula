# desktop module

**Location:** `modules/desktop/flake.nix`  
**Module name:** `desktop` (imported as a role dependency, not directly via `modules`)  
**Options namespaces:** `services.desktop` (system), `homeManager.desktop` (home-manager)

---

## Why this module exists

Hyprland + a usable desktop requires a significant amount of coordinated NixOS and home-manager configuration: the compositor, display manager, XDG portals, GTK/Qt theming, cursor, dconf dark mode, session environment variables, and the hyprland.conf dotfile. Scattering these across every role that needs a desktop leads to duplication and drift.

This module captures all of that as a single composable unit. Roles that need a desktop import it and set `services.desktop.enable = true`; everything else is handled.

---

## Structure

The module exports two fragments:

### `nixosModules.default` — system level

Configured via `services.desktop.*`. Handles:

- **Hyprland** — `programs.hyprland` with optional UWSM integration and XWayland.
- **Display manager** — SDDM by default, Wayland mode enabled.
- **XDG portals** — `xdg-desktop-portal-hyprland` for screen sharing and file pickers.
- **Qt theming** — `qt.platformTheme = "gnome"` + `style = "adwaita-dark"` so Qt apps match GTK apps fleet-wide without per-user configuration.
- **Theme packages** — `adwaita-qt`, `adwaita-qt6`, `gnome-themes-extra`, `adwaita-icon-theme`, bibata cursor package installed at the system level so they are available before login.
- **Autostart** — optional list of shell commands launched as a oneshot systemd service at session start.
- **Wayland session variables** — `NIXOS_OZONE_WL=1` set system-wide.
- **Hardware** — `hardware.enableAllFirmware = true` (requires `nixpkgs.config.allowUnfree`).

### `homeManagerModules.default` — user dotfiles level

Configured via `homeManager.desktop.*`. Handles:

- **`~/.config/hypr/hyprland.conf`** — deployed from `modules/desktop/hypr/hyprland.conf` with `force = true` so home-manager always wins over Hyprland's auto-generated file.
- **GTK theme** — Adwaita-dark, Adwaita icons, Bibata cursor via `gtk.*`.
- **dconf** — `prefer-dark`, `gtk-theme`, `icon-theme`, `cursor-theme` written to the GNOME settings bus so GTK4 apps and anything that reads XDG color-scheme go dark automatically.
- **`home.pointerCursor`** — sets the Wayland cursor for the whole session.
- **Session variables** — `GTK_THEME=Adwaita:dark`, `XCURSOR_THEME`, `XCURSOR_SIZE`, `HYPRCURSOR_THEME`, `HYPRCURSOR_SIZE`. `GTK_THEME` is what app launchers like fuzzel actually read at runtime to pick the correct theme.
- **`programs.fuzzel.enable`** — the app launcher bound to `Super+R`.
- **Home packages** — `dunst` (notifications), `wl-clipboard`.

---

## Theming decisions

### Why Adwaita-dark

Adwaita is the reference GTK theme. Using the `-dark` variant via both `gtk.theme.name` and `dconf` ensures coverage for both GTK3 apps (which read `gtk.theme`) and GTK4 apps (which read the dconf color-scheme). Without both, some apps go dark and others stay light.

### Why `GTK_THEME` in session variables

GTK apps launched outside a full GNOME session (e.g. via fuzzel, from the terminal) don't always read dconf. `GTK_THEME=Adwaita:dark` is the environment variable fallback that these apps check first. Without it, fuzzel and similar launchers render with the default light theme regardless of what dconf says.

### Why bibata cursor

Hardware-accelerated, clean design, available in nixpkgs. The cursor name `Bibata-Modern-Classic` is used consistently across `gtk.cursorTheme`, `home.pointerCursor`, dconf, and the `HYPRCURSOR_*` env vars so all three cursor-setting mechanisms agree.

---

## hyprland.conf notes

The bundled config at `modules/desktop/hypr/hyprland.conf` is a curated baseline:

- `$menu = fuzzel` — not wofi. Fuzzel is already enabled via `programs.fuzzel.enable` and respects `GTK_THEME`.
- Inline `input { }` block — the original config sourced `~/.config/hypr/mouse.conf` which doesn't exist on a fresh install and causes Hyprland to log a globbing error on every startup.
- Mouse accel disabled (`accel_profile = flat`, `force_no_accel = true`) — raw input for gaming/precision work.

A custom hyprland.conf can be substituted per-machine via `homeManager.desktop.hyprConfigSource = ./path/to/hyprland.conf`.

---

## Options reference

```nix
# System level (in NixOS module)
services.desktop = {
  enable = true;
  hyprland = { enable = true; withUWSM = true; xwaylandEnable = true; };
  displayManager = { enable = true; manager = "sddm"; waylandEnable = true; };
  theme = { enable = true; cursor = { name = "Bibata-Modern-Classic"; size = 24; }; };
  autostart = [ "waybar &" "nm-applet &" ];
};

# User level (in home-manager module)
homeManager.desktop = {
  enable = true;
  hyprConfigSource = null;  # null = use bundled config
  extraHomePackages = [];
  theme = { enable = true; cursor = { size = 24; }; };
};
```
