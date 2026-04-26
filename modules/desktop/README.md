# Desktop module (Hyprland) — README

This module provides a composable, parameterized Hyprland-based desktop stack that is intended to be imported by role flakes (e.g. `testing`) or consumed directly in a host configuration. It is intentionally lightweight: the module supplies sensible system defaults and an optional home-manager fragment so user dotfiles (for example `hyprland.conf`) can be managed from the repository.

Location
- System-level module (flake output): `modules/desktop/flake.nix`
- Example Hyprland config bundled in the repo: `modules/desktop/hypr/hyprland.conf`
- Per-software home-manager fragments: `modules/desktop/home-modules/hypr/hypr-conf.nix` (hyprland config + fuzzel)

What this module does (high-level)
- Provides a `services.desktop` option namespace to enable Hyprland, related packages and helper defaults.
- Wires portal packages (for screen sharing / file pickers) and a display manager (SDDM by default) when enabled.
- Exposes an optional home-manager fragment so a user can have the repo-managed `hyprland.conf` installed at `~/.config/hypr/hyprland.conf`.
- Is safe to include in role flakes; it does not force activation unless `services.desktop.enable` is set.

Important options (see the flake for exact option names)
- `services.desktop.enable` (bool): master switch for the desktop convenience module.
- `services.desktop.packages` (list of packages): system packages installed for desktop workflows.
- `services.desktop.hyprland.enable`, `withUWSM`, `xwayland.enable`: Hyprland-specific toggles.
- `services.desktop.displayManager.*`: control display manager enablement and behavior.
- `services.desktop.homeManager.exposeHyprConfig` (bool): when true, the module exposes a home-manager fragment that installs `hyprland.conf`.
- `services.desktop.homeManager.hyprConfigSource` (string or null): source path (relative to the flake or host config) used as the content for `~/.config/hypr/hyprland.conf` when `exposeHyprConfig` is enabled.
- `services.desktop.autostart` (list of strings): commands to autostart (helper support is provided, but many prefer to use `hyprland.conf`'s `exec-once`).

How to enable (examples)

1) Enable via role flake (recommended when you want the `testing` role to include desktop by default)
- The `testing` role in this repo already includes the desktop module by default.
- To override or pass extra desktop configuration from the host, set per-machine fields in `inventory/machines.json` (the top-level flake forwards `machine` into `_module.args`).

Example addition to `inventory/machines.json`:
```json
{
  "machines": {
    "testbed": {
      "hostname": "testbed",
      "primaryUser": "voyager",
      "packs": ["testing"],
      "desktopHomeManager": true,
      "desktopHyprConfigSource": "./modules/desktop/hypr/hyprland.conf"
    }
  }
}
```
- `desktopHomeManager: true` will cause `services.desktop.homeManager.exposeHyprConfig` to be true for that host.
- `desktopHyprConfigSource` points to the config file in the repo (adjust the path if your host `configuration.nix` is in a different relative location).

2) Enable in a host `configuration.nix` (explicit host-level override)
```nix
{ ... }:
{
  services.desktop.enable = true;
  services.desktop.hyprland.enable = true;
  services.desktop.homeManager.exposeHyprConfig = true;
  services.desktop.homeManager.hyprConfigSource = ./modules/desktop/hypr/hyprland.conf;
}
```
- If you use home-manager as part of NixOS (`home-manager.nixosModules.home-manager`), ensure you include the module fragment or the module’s shared home-manager module into `home-manager.sharedModules` or the user's `home.nix`.

Using the home-manager fragment
- The desktop flake exposes a home-manager fragment to place `~/.config/hypr/hyprland.conf` from a source file in the repo.
- Typical pattern:
  - Include `home-manager` in your `nixosConfigurations` modules.
  - In the `home-manager.users.<user>` config, import or enable the desktop fragment, and set `hyprConfigSource` to the repository path.
- Example snippet in `home-manager` user config:
```nix
{ config, pkgs, ... }:
{
  # Import the hypr home-module fragment directly:
  let hyprMods = import <path-to>/modules/desktop/home-modules/hypr/hypr-conf.nix { inherit pkgs lib; }; in
  {
    imports = [ hyprMods.hypr ];
    homeManager.desktop.enable = true;
    homeManager.desktop.hyprConfigSource = ../modules/desktop/hypr/hyprland.conf;
}
```
(Adjust the import/source paths to match your repository layout and where `home.nix` is evaluated from.)

Best practices & notes
- Keep `hyprland.conf` under `modules/desktop/hypr/` (or another repo path) and reference it via `hyprConfigSource` so the config remains versioned and reproducible.
- Prefer enabling the module via role flakes so many hosts can inherit the same defaults, and use host-level overrides for per-device tweaks.
- When using `home-manager` integration, ensure the build environment has access to any secrets or assets required by the home fragment (e.g., icons, wallpapers), and prefer read-only repository sources for dotfiles.
- If you use `autostart` via the module, consider adding the same autostart entries to `hyprland.conf` if you want them guaranteed inside the Wayland session (some users prefer `exec-once` semantics in the Hyprland config).

If you want, I can:
- Add a small example `home.nix` that imports the module's home fragment and demonstrates a minimal `homeManager.desktop` configuration.
- Add CI checks that validate `nix build .#nixosConfigurations.<host>` succeeds without needing secrets before you attach the USB / key material.

— I can make those follow-ups if you want them committed.