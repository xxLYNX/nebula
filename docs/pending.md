# Migration Pending

Tracks everything from `pluto-config` not yet in nebula.
Check off items as they are migrated into a module or role.

---

## Browsers
- [x] Browser installed — zen-browser via `modules/web-utils` *(new, replaces brave)*
- [ ] `programs.firefox.enable = true` *(was in pluto-config; skip or add to web-utils)*
- [ ] `brave` *(replace entirely with zen-browser)*

---

## System Packages (not yet in any module)
- [ ] `zip` / `unzip`
- [ ] `wget`
- [ ] `htop`
- [ ] `tree`
- [ ] `pavucontrol` (audio control GUI)
- [ ] `networkmanagerapplet` / `nm-applet`
- [ ] `superfile` / `nnn` (file managers)
- [ ] `bind.dnsutils`
- [ ] `adwaita-qt` / `adwaita-qt6` (Qt theming)
- [ ] `libreoffice-qt` + `hunspell` + `hunspellDicts.uk_UA` / `hunspellDicts.th_TH`
- [ ] `bitwarden-desktop` + `bitwarden-cli`
- [ ] `vesktop` (Discord client)
- [ ] `beeper`
- [ ] `prismlauncher` (Minecraft launcher)
- [ ] `calibre` (eBook manager)
- [ ] `bluemail`
- [ ] `zed-editor`
- [ ] `socat`
- [ ] `ouch` (archive tool)
- [ ] `btop`
- [ ] `libnotify` (notify-send)
- [ ] `wlr-randr`
- [ ] `libratbag` (mouse config library)
- [ ] `wev` ✅ already in `modules/desktop`

---

## Development Tools (consider a `dev` module)
- [ ] `go` + `gopls` + `gotools` + `delve`
- [ ] `gcc`
- [ ] `ffmpeg-full` *(requires allowUnfree)*
- [ ] `python3` with numpy, pillow
- [ ] `texliveFull`
- [ ] `typescript` + `typescript-language-server` + `eslint` + `prettier`
- [ ] `bash-language-server` + `shellcheck` + `shfmt`
- [ ] `ripgrep` + `file`
- [ ] `golangci-lint` + `gofumpt`

---

## Custom Packages
- [ ] `vapoursynth-rife-ncnn-vulkan` — custom derivation at `pluto-config/pkgs/vapoursynth-rife-ncnn-vulkan.nix`
  - Needs: `vs-overlay` flake input, `vapoursynth.withPlugins [...]`
  - Blocked on: deciding where custom pkgs live in nebula

---

## Home-Manager Programs
- [ ] `programs.nixvim` — full config with moonfly colorscheme, treesitter, LSP (go, ts, bash), linters, formatters, copilot, codecompanion
- [ ] `programs.vscode` — vscodium, dracula theme, vim extension, markdown extension
- [ ] `programs.tmux` — mouse, sensible/yank/continuum/resurrect plugins
- [ ] `programs.thunderbird` — software render workarounds
- [ ] `programs.yazi` — RAR support, ouch plugin
- [ ] `programs.fuzzel` config ✅ package installed; fuzzel settings (colors, border) not yet migrated

---

## Theming / Appearance
- [x] GTK dark theme — `programs.gtk` with Adwaita-dark *(in desktop homeManagerModules)*
- [x] Qt theming — `qt.enable`, `qt.platformTheme = "gnome"`, `qt.style = "adwaita-dark"` *(in desktop nixosModules)*
- [x] dconf dark mode — `dconf.settings."org/gnome/desktop/interface"` *(in desktop homeManagerModules)*
- [x] Bibata cursor — `home.pointerCursor` with `bibata-cursors`, size 24 *(in desktop homeManagerModules)*
- [x] Session variables: `XCURSOR_THEME`, `XCURSOR_SIZE`, `HYPRCURSOR_THEME`, `HYPRCURSOR_SIZE` *(in desktop homeManagerModules)*
- [x] Packages: `gnome-themes-extra`, `adwaita-icon-theme`, `bibata-cursors`, `adwaita-qt`, `adwaita-qt6` *(in desktop nixosModules)*

---

## Hardware & System Settings
- [ ] `time.timeZone` — not set (defaults to UTC)
- [ ] `i18n.defaultLocale = "en_US.UTF-8"`
- [ ] `console.useXkbConfig = true` + `console.font = "Lat2-Terminus16"`
- [ ] `boot.kernelPackages = pkgs.linuxPackages_latest`
- [ ] `boot.loader.systemd-boot.configurationLimit = 25` *(only 5s timeout set so far)*
- [ ] `boot.resumeDevice` (swap resume — needs disk label)
- [ ] `hardware.bluetooth.enable = true` + `powerOnBoot`, `FastConnectable`, `Experimental`, `AutoEnable`
- [ ] `services.blueman.enable = true`
- [ ] `services.thermald.enable = true`
- [ ] `services.auto-cpufreq.enable = true`
- [ ] `services.libinput.enable = true`
- [ ] `services.ratbagd.enable = true` (mouse DPI config daemon)
- [ ] `services.pipewire.alsa.support32Bit = true` *(only basic alsa set so far)*
- [ ] `security.rtkit.enable = true` (PipeWire recommendation)
- [ ] `programs.thunar.enable = true`
- [ ] `programs.nm-applet.enable = true`

---

## Gaming (consider a `gaming` module)
- [ ] `programs.steam.enable = true` + `gamescopeSession`, `remotePlay.openFirewall`, `dedicatedServer.openFirewall`
- [ ] `programs.gamemode.enable = true`

---

## Nix Housekeeping
- [ ] `nix.gc.automatic = true` + `dates = "weekly"` + `--delete-older-than 30d`
- [ ] `nix.settings.trusted-users = [ "root" primaryUser ]`
- [ ] `nixpkgs.config.allowUnfreePredicate = _: true`
- [ ] `system.autoUpgrade` — point to nebula repo once stable

---

## User Services (home-manager)
- [ ] `clipse` clipboard manager + systemd user service (`graphical-session.target`)
- [ ] `services.udiskie` — auto-mount, notify, tray
- [ ] `services.dunst` — full config (colors, geometry, urgency levels)

---

## SSH
- [ ] `programs.ssh.startAgent = true`
- [ ] `programs.ssh.enableAskPassword = true`
- [ ] `programs.ssh.extraConfig` — `AddKeysToAgent yes`, `IdentityFile ~/.ssh/github-xxlynx`

---

## Scripts / Automation
- [ ] `squeak.sh` — ratbagctl DPI switcher, install to `~/.local/bin/squeak.sh`
- [ ] `tiles.sh` — Hyprland monitor hotplug handler + `tiles-monitor` systemd user service
  - Handles HDMI-A-1 connect/disconnect, DPMS, tiny resolution fallback

---

## Roles / Profiles Not Yet Ported
- [ ] `security-host` role — SOPS secrets (`sops-nix`), `secrets/secrets.yaml`, age key at `/var/lib/sops-nix/key.txt`
- [ ] `util-host` role — obsidian, syncthing (with `openDefaultPorts`)

---

## Hyprland Config Details (partially migrated)
- [x] `hyprland.conf` managed by home-manager ✅
- [x] Monitor layout (eDP-1, HDMI-A-1) ✅
- [x] Keybindings, animations, decoration ✅
- [x] Input block (inline, was sourced from missing mouse.conf) ✅
- [ ] `$fileManager = dolphin` — dolphin not installed; `superfile`/`nnn` pending
- [ ] Clipse window rule (float, 622x652) — depends on clipse being installed
- [ ] `gesture = 3, horizontal, workspace` — fine but untested on testbed
