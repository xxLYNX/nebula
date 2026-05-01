# Nebula — Known Issues and Design Debt

Identified through full codebase review. Not all items are equally urgent; each entry notes
the affected file(s) and why it matters.

---

## 1. Enable flags everywhere — violates "import = used"

**Files:** `modules/desktop/flake.nix`, `modules/web-utils/flake.nix`,
`modules/maintenance/flake.nix`, `modules/security-host/flake.nix`

Every composable module defines an `enable` option (default `false` or `true`) and wraps all
config in `lib.mkIf cfg.enable`. This forces roles to explicitly set `services.desktop.enable = true`,
`services.webUtils.enable = true`, etc. after importing the module — contradicting the core tenet
that importing a module means using it. The enable guard belongs at the call site (the role),
not inside the module. Remove the master switches; let the role flake configure unconditionally.

---

## 2. `nixvim.nix` is unconditional while every other home fragment isn't

**File:** `modules/desktop/home/nixvim.nix`

All other home fragments (`hyprland.nix`, `fuzzel.nix`, `kitty.nix`, `dunst.nix`,
`themes/nebula/home.nix`) are wrapped in `lib.mkIf (hmCfg.enable or false)`. `nixvim.nix` has
no such guard — it unconditionally sets `programs.nixvim.enable = true`. If a role sets
`homeManager.desktop.enable = false` the user gets nixvim but no terminal, launcher, or
notifications. Either all fragments are unconditional (preferred) or all respect the flag.
Right now the two halves of the home module are inconsistent.

---

## 3. `testing` and `pluto` roles are copy-paste clones

**Files:** `roles/testing/flake.nix`, `roles/pluto/flake.nix`

The two role flakes are structurally identical: same disko layout, same `boot.loader.*`, same
`nix.settings`, same `nix.gc`, same `environment.systemPackages`, same `services.openssh`,
`services.avahi`, `security.sudo`, `home-manager.users` wiring. The only thing that will
diverge is per-machine intent. All the shared boilerplate is duplicated — changes to nix settings,
boot config, or GC policy must be made in both files. Extract a shared `roles/common` or
`modules/nixos/base` module.

---

## 4. Defensive `machine != null` guards are dead code

**Files:** `roles/testing/flake.nix`, `roles/pluto/flake.nix`

```nix
diskDevice = if machine != null then (machine.hardware.disk.device or "/dev/sda") else "/dev/sda";
```

`machine` is always injected via `_module.args.machine` in `mkHost`. It is never `null` — if it
were, the build would fail well before reaching these bindings. The fallback values are dead paths
that also silently mask a missing inventory entry rather than failing loudly.

---

## 5. `defaultPackages` duplicates home-manager managed packages

**File:** `modules/desktop/flake.nix`

The `defaultPackages` list (used as the default for `services.desktop.packages`) includes `kitty`,
`dunst`, `fuzzel`, and `wev`. `kitty`, `dunst`, and `fuzzel` are already installed as user packages
by `programs.kitty`, `services.dunst`, and `programs.fuzzel` in the home fragments. Installing
them twice (system-wide and per-user) is redundant. `wev` (Wayland event viewer) is a debug tool
and has no business being a default production package. `hyprland` and
`xdg-desktop-portal-hyprland` are installed via `programs.hyprland.enable` in the system
fragment — also redundant in the list.

---

## 6. `security-host` module instantiates x86_64 pkgs at flake eval time

**File:** `modules/security-host/flake.nix`

```nix
pkgs = import nixpkgs { system = "x86_64-linux"; };
```

This is evaluated at flake output time for every consuming system. On any non-x86_64 host this
silently evaluates the wrong package set. The module receives `pkgs` as a NixOS module argument
and should use that instead. The top-level `pkgs` binding is only used to construct `lib`, which
doesn't need a system-specific instantiation at all (`lib = nixpkgs.lib` is sufficient).

---

## 7. `desktop/flake.nix` instantiates x86_64 pkgs for option defaults

**File:** `modules/desktop/flake.nix`

```nix
pkgs = import nixpkgs { system = "x86_64-linux"; };
```

Used only to build the `defaultPackages` list that backs the `services.desktop.packages` option
default. On an aarch64 host the default would reference x86_64 package derivations. Use
`pkgs.${system}` or defer the default to the module's own `pkgs` argument.

---

## 8. `security-host` is a dead root flake input

**File:** `flake.nix`

`security-host` is declared as a root flake input and would be injected via `inputs` into every
host's module args. Neither `testbed` nor `pluto` lists it in `os.modules`, so it is never
evaluated. Remove it from root inputs until a machine actually uses it, to avoid pulling the
flake into lockfile resolution unnecessarily.

---

## 9. `sops-nix` imported unconditionally for every host with no secrets defined

**File:** `flake.nix` (`mkHost`)

`sops-nix.nixosModules.sops` is unconditionally added to every host's imports regardless of
whether that host has any secrets. There are no `.sops.yaml` files, no `sops` key declarations,
and no `age`/`gpg` keys configured anywhere in the repo. This adds evaluation overhead and a
required key file on every host for zero current benefit. Move it to an opt-in module or add
secrets.

---

## 10. `MOZ_ENABLE_WAYLAND = "0"` disables Firefox Wayland on a Wayland desktop

**File:** `modules/desktop/system/hyprland.nix`

```nix
environment.sessionVariables = {
  NIXOS_OZONE_WL  = "1";
  MOZ_ENABLE_WAYLAND = "0";   # ← disables Firefox Wayland
};
```

`NIXOS_OZONE_WL = "1"` enables Wayland for Electron/Chromium apps. `MOZ_ENABLE_WAYLAND = "0"`
simultaneously disables it for Firefox. This is contradictory on a Wayland-first desktop.
Firefox has auto-detected Wayland since v121; the variable can be removed or set to `"1"`.

---

## 11. `hyprland.conf` contains laptop-specific monitor config

**File:** `modules/desktop/themes/nebula/compositor/hyprland.conf`

```
monitor = eDP-1, 3840x2160@60, 0x0, 2
monitor = HDMI-A-1, 1920x1080@120, auto, 1
```

`eDP-1` is an internal laptop display connector. This config is shared with every machine
including `pluto` (desktop). Hyprland will emit warnings/errors for connectors that don't exist.
Per-machine monitor config belongs in `hosts/<hostname>/hyprland.conf` or as an inventory field,
not in the shared compositor config.

---

## 12. `description` key in `security-host` options is invalid NixOS module syntax

**File:** `modules/security-host/flake.nix`

```nix
options.services.securityHost = {
  description = "Top-level options for the security-host convenience module";
  enable = lib.mkOption { ... };
  ...
};
```

A bare string at the options attribute level is not a valid NixOS option definition. The NixOS
module system expects every attribute in an options namespace to be either a `lib.mkOption {}`
call or a nested attrset of options. This will produce an evaluation error when the module is
first imported by a machine. The `description` string should be removed (it belongs in a comment,
not the options attrset).

---

## 13. `cfg = config.services.desktop or {}` masks real config structure

**Files:** `modules/desktop/flake.nix`, `modules/desktop/system/hyprland.nix`,
`modules/desktop/system/packages.nix`, `modules/desktop/home/*.nix`

The `or {}` fallback is used throughout to read option values as if the options might not exist.
Since the options are declared in the same module evaluation, `config.services.desktop` will
always be present. Using `or {}` hides typos in option paths (e.g. `cfg.hyprland.withUWSM or
true` would silently return `true` even if the path were wrong). Use the typed options directly.

---

## 14. `xdg_portals` option uses snake_case

**File:** `modules/desktop/flake.nix`

All other options in `services.desktop` use camelCase (`withUWSM`, `xwaylandEnable`,
`waylandEnable`, `displayManager`). `xdg_portals` uses snake_case — inconsistent with the rest
of the namespace.

---

## 15. `dunst.nix` has a hardcoded non-theme `frame_color`

**File:** `modules/desktop/home/dunst.nix`

```nix
frame_color = "#888888";
```

This is in the `global` dunst section and sets the default notification frame colour to a
hardcoded grey, overriding the nebula palette. `urgency_critical` correctly uses `bord` from the
palette, but the global default ignores it. Should use `"#${theme.border}"` for consistency.

---

## 16. `machine = machine;` should be `inherit machine`

**File:** `flake.nix`

```nix
_module.args = {
  inherit inputs;
  primaryUser = builtins.head machine.users.admin;
  machine = machine;   # ← redundant self-assignment
};
```

Minor style inconsistency with the `inherit inputs` on the line above. Should be `inherit machine;`.

---

## 18. `users.admin` only wires up the first entry; `users.regular` is never read

**Files:** `flake.nix`, `roles/testing/flake.nix`, `roles/pluto/flake.nix`

`flake.nix` derives `primaryUser` as `builtins.head machine.users.admin` and passes only that
single string to role flakes. Both role flakes create exactly one user from `${primaryUser}` with
`extraGroups = [ "wheel" "networkmanager" ]`. Any additional names in `users.admin` are silently
ignored — no account is created and no wheel membership granted. The schema implies the array
supports multiple admins; it doesn't.

`users.regular` is accepted by the schema and the JSON, and never referenced anywhere in the
codebase. No accounts are created for regular users regardless of what is listed.

---

## 17. `roles/security-host/` directory is empty / stub

**Directory:** `roles/security-host/`

The directory exists (referenced in workspace structure) but there is no `flake.nix` inside it.
It is not referenced from the root flake inputs. Either it was abandoned mid-creation or the
intent was to use `modules/security-host` directly as a role. The empty directory is misleading.

---

## 19. `$mainMod, R` is bound twice in `hyprland.conf` — opens two fuzzel instances

**File:** `modules/desktop/themes/nebula/compositor/hyprland.conf`

```
bind = $mainMod, R, exec, $menu       # line 221 — $menu = fuzzel
...
bind = $mainMod, R, exec, fuzzel      # line 282 — explicit duplicate
```

Hyprland fires every matching bind. Pressing `$mainMod + R` opens two fuzzel instances
simultaneously. One of the two binds must be removed.

---

## 20. `clipse`, `dolphin`, `playerctl`, and `brightnessctl` referenced in `hyprland.conf` but not installed

**File:** `modules/desktop/themes/nebula/compositor/hyprland.conf`

```
$fileManager = dolphin         # bind $mainMod,E — dolphin not in any packages
exec, kitty --class clipse -e clipse  # bind ALT,C — clipse not in any packages
bindl = , XF86AudioNext, exec, playerctl ...   # playerctl not installed
bindel = ,XF86MonBrightnessUp, exec, brightnessctl ...  # brightnessctl not installed
```

`clipse` existed in `old-config/pluto-config/modules/clipboard.nix` but was never migrated.
All four binds will silently do nothing at runtime. Packages need to be added to the desktop
system/home packages, or the binds need to be removed.

---

## 21. `$mainMod, W` launches `firefox` but zen-browser is the configured default

**File:** `modules/desktop/themes/nebula/compositor/hyprland.conf`

```
bind = $mainMod, W, exec, firefox
```

`modules/web-utils` sets zen-browser as the system default browser and does not install Firefox.
This bind silently fails on any machine with `web-utils` in `os.modules`. Should be
`exec, zen` (or whatever the zen-browser binary is named in the community flake).

---

## 22. No `nix-community` cachix substituter — nixvim will rebuild from source on every deploy

**Files:** `roles/testing/flake.nix`, `roles/pluto/flake.nix`

`nix.settings.substituters` only lists `cache.nixos.org` and `colmena.cachix.org`. nixvim is not
in the NixOS binary cache. The nix-community cache (`nix-community.cachix.org`) contains
prebuilt nixvim closures and is explicitly recommended in the nixvim documentation. Without it,
every `colmena apply` or rebuild that touches nixvim triggers a multi-hour source compile on the
target machine.

Add to substituters:
```
"https://nix-community.cachix.org"
```
And to trusted-public-keys:
```
"nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Bg="
```

---

## 23. `home-manager.useGlobalPkgs` and `home-manager.useUserPackages` not set

**File:** `flake.nix` (`mkHost`)

The root flake imports `home-manager.nixosModules.home-manager` but neither
`home-manager.useGlobalPkgs` nor `home-manager.useUserPackages` is set anywhere.

- Without `useGlobalPkgs = true`: home-manager imports its own separate nixpkgs instance,
  doubling eval memory and risking package version drift between system and user environments.
- Without `useUserPackages = true`: packages declared in `home.packages` are installed into
  `~/.nix-profile` rather than the system profile, which means they don't appear in
  `environment.etc."profile.d"` and can be shadowed by system packages unexpectedly.

Both should be set to `true` in `home-manager.` options inside `mkHost`.

---

## 24. `colorscheme = "moonfly"` is redundant alongside `colorschemes.moonfly.enable = true`

**File:** `modules/desktop/home/nixvim.nix`

```nix
colorschemes.moonfly.enable = true;
colorscheme = "moonfly";
```

In nixvim, `colorschemes.<name>.enable = true` installs the plugin and sets the colorscheme
automatically. The explicit `colorscheme = "moonfly"` line is a no-op in current nixvim versions
and carries over from older nixvim where both were required. Remove the duplicate.

---

## 25. Tab keymap conflict between `extraConfigLua` and `plugins.cmp.settings.mapping`

**File:** `modules/desktop/home/nixvim.nix`

`extraConfigLua` defines a `<Tab>` cmp mapping that **confirms** the selected item:
```lua
["<Tab>"] = cmp.mapping(function(fallback)
  if cmp.visible() then cmp.confirm({ select = true }) else fallback() end
end, { "i", "s" })
```

`plugins.cmp.settings.mapping` also defines `<tab>` to **open** the completion menu:
```nix
"<tab>" = "cmp.mapping.complete()";
```

These two definitions target the same key with opposite semantics. The one evaluated last wins,
but which that is depends on nixvim's internal ordering. The result is unpredictable tab behavior
in insert mode. One mapping should be removed.

---

## 26. Role nixpkgs `url` fields are misleading dead declarations

**Files:** `roles/testing/flake.nix`, `roles/pluto/flake.nix`

Both role flakes declare:
```nix
nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
```

But also have `inputs.nixpkgs.follows = "nixpkgs"` (via the root flake's follows override),
which completely replaces this URL with the root's pinned commit. The `url` field is never used
when consumed from the root flake. A reader of a role file alone sees `nixos-unstable` and
reasonably assumes that's what's used — it isn't. The URL should be removed or replaced with a
comment explaining that the root flake controls the pin.

---

## 27. `security.sudo.wheelNeedsPassword = false` set on both roles silently

**Files:** `roles/testing/flake.nix`, `roles/pluto/flake.nix`

Both the testing and pluto roles set `security.sudo.wheelNeedsPassword = false`, overriding
the desktop module's `lib.mkDefault true`. This means every machine in the fleet — including
pluto, a production workstation — has passwordless sudo for all wheel users. Combined with
`services.openssh.enable = true` (also on both roles), an attacker who gains shell access via
SSH immediately has root with no further authentication. The testing role has a comment
acknowledging this; the pluto role has no comment. At minimum pluto should restore password
requirement for sudo.

**Fixed (pluto):** `services.openssh.enable = false` and `security.sudo.wheelNeedsPassword = true` set in `roles/pluto/flake.nix`. Testing role retains passwordless sudo intentionally.

---

## 28. `gesture = 3, horizontal, workspace` is not valid Hyprland syntax

**File:** `modules/desktop/themes/nebula/compositor/hyprland.conf`

```
gesture = 3, horizontal, workspace
```

This is not valid Hyprland configuration syntax. Hyprland gestures are configured via
`gestures { }` blocks or `bindgesture` / `bind` directives depending on the version. This line
will be silently ignored by Hyprland. Three-finger horizontal swipe to switch workspaces is not
actually wired up.

---

## 29. Stray `# Test comment from repo` at end of `hyprland.conf`

**File:** `modules/desktop/themes/nebula/compositor/hyprland.conf`

A `# Test comment from repo` line appears at the very end of the file. This is uncommitted
debug noise and should be removed.

---

## 30. `copilot-vim` is enabled but no `cmp-copilot` source is configured

**File:** `modules/desktop/home/nixvim.nix`

`plugins.copilot-vim` is enabled and works as a standalone inline suggestion tool. However,
`plugins.cmp.settings.sources` only lists `nvim_lsp`, `path`, and `buffer` — there is no
`copilot` source. This means Copilot suggestions appear as ghost text (via copilot-vim) but
never surface inside the cmp popup menu. Whether this is intentional is not documented. If the
intent is to have Copilot completions in the popup, `cmp-copilot` must be added as a source.
If ghost-text-only is intentional, a comment should say so to prevent a future "fix" that
introduces a duplicate completion path.

---

## 31. `hyprland.conf` RGBA border and shadow values duplicated from `colors.nix`

**File:** `modules/desktop/themes/nebula/compositor/hyprland.conf`

```
col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
col.inactive_border = rgba(595959aa)
color = rgba(1a1a1aee)   # shadow
```

These values are already defined in `themes/nebula/colors.nix` as `activeBorderHypr`,
`inactiveBorderHypr`, and `shadowHypr`. The compositor config duplicates them as raw strings
instead of templating them from the palette. If the palette changes, `hyprland.conf` won't
update. The file should be generated via a Nix expression (e.g. `pkgs.writeText` or
`home.file`) that interpolates `colors.nix` values, rather than being a static file.

---

## 32. LSP binaries managed via `home.packages` instead of nixvim server `package` option

**File:** `modules/desktop/home/nixvim.nix`

Each LSP server (`gopls`, `ts_ls`, `bashls`, `nixd`) is enabled with `enable = true` but no
`package` option is set. nixvim then resolves the binary by name from `$PATH`. The binaries are
provided by `home.packages` (`gopls`, `typescript-language-server`, etc.), which works, but
creates two separate management points for the same tool. The idiomatic nixvim pattern is:

```nix
servers.gopls = { enable = true; package = pkgs.gopls; };
```

With the `package` option set, nixvim manages the binary directly in the plugin closure and
`home.packages` entries become redundant and can be removed. Without it, removing a binary from
`home.packages` silently breaks the LSP server with no error at eval time.

---

## 33. `colmena.packages.${pkgs.system}.colmena` will fail on non-x86_64/aarch64 hosts

**File:** `flake.nix` (`mkHost`)

```nix
({ pkgs, ... }: {
  environment.systemPackages = [ colmena.packages.${pkgs.system}.colmena ];
})
```

Colmena only publishes packages for `x86_64-linux` and `aarch64-linux`. If a future host uses
any other system string (e.g. `riscv64-linux`, `x86_64-darwin`), this attribute access will
throw at eval time with a cryptic "attribute missing" error rather than a meaningful message.
Should guard with `lib.optionalAttrs` or check system membership before dereferencing.

---

## 34. `$mainMod, M` exits Hyprland immediately with no confirmation

**File:** `modules/desktop/themes/nebula/compositor/hyprland.conf`

```
bind = $mainMod, M, exit,
```

`Super + M` terminates the Hyprland session immediately, closing all windows and returning to
the display manager. There is no confirmation prompt. This is adjacent to `Super + C`
(kill active window) — a slip of the finger kills the entire desktop. Consider removing the
bind, remapping it to a less collision-prone chord, or replacing it with a script that
prompts for confirmation.

---

## Summary by priority

| Priority | Item |
|----------|------|
| Bug / will fail | 12 — invalid `description` in security-host options |
| Bug / wrong behaviour | 10 — `MOZ_ENABLE_WAYLAND = "0"` ✅ fixed |
| Bug / wrong behaviour | 19 — `$mainMod, R` double-bound, opens two fuzzels |
| Bug / wrong behaviour | 25 — Tab keymap conflict in nixvim cmp |
| Bug / wrong behaviour | 28 — `gesture =` invalid syntax, swipe not wired |
| Bug / missing deps | 20 — clipse/dolphin/playerctl/brightnessctl not installed |
| Bug / missing deps | 21 — `firefox` bind, zen-browser is default |
| Bug / per-machine bleed | 11 — laptop monitor config in shared hyprland.conf |
| Performance | 22 — no nix-community cachix, nixvim rebuilds from source |
| Correctness | 23 — `home-manager.useGlobalPkgs`/`useUserPackages` not set |
| Security | 27 — passwordless sudo on all roles incl. production pluto |
| Design tenet | 1 — enable flags in every module |
| Design tenet | 2 — nixvim unconditional vs rest conditional |
| Design tenet | 4 — dead null guards |
| DRY | 3 — testing/pluto role duplication |
| DRY | 5 — defaultPackages duplicates hm-managed packages ✅ fixed |
| Correctness | 6 — security-host x86_64 pkgs |
| Correctness | 7 — desktop x86_64 pkgs for defaults |
| Dead code | 8 — security-host dead root input |
| Dead code | 9 — sops-nix with no secrets |
| Dead code | 17 — empty roles/security-host/ directory |
| Dead code / broken contract | 18 — users.admin only wires first entry; users.regular never read |
| Dead code | 24 — redundant `colorscheme = "moonfly"` |
| Dead code | 26 — misleading nixpkgs url in role inputs |
| Dead code | 29 — stray debug comment in hyprland.conf |
| Unclear intent | 30 — copilot-vim enabled but no cmp-copilot source |
| DRY / theme drift | 31 — hyprland.conf RGBA values duplicated from colors.nix |
| Maintainability | 32 — LSP binaries in home.packages instead of server package option |
| Correctness | 33 — colmena package reference breaks on non-x86_64/aarch64 hosts |
| UX / accidental | 34 — `$mainMod, M` exits Hyprland with no confirmation |
| Style | 13 — `or {}` guards |
| Style | 14 — snake_case option name |
| Style | 15 — hardcoded dunst frame_color |
| Style | 16 — `machine = machine` vs `inherit` |
