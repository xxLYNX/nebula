# Planned capabilities

Future features and workstation/fleet capabilities we intend to add or redesign. This is **not** a bug list (`docs/issues.md`), **not** the active sprint (`docs/current-sprint.md`), and **not** the old-config migration checklist (`docs/pending.md`).

Use this doc when scoping a larger rework (module splits, role cleanup, desktop/nixvim overhaul). Items here should be actionable enough to turn into modules, host config, or nixvim options when we pick them up.

**Status key:** `idea` → `design` → `ready` → `done` (move to module README or delete when shipped)

---

## Writing, notes, and system-wide text input

**Status:** `design` — revisit during the planned desktop / nixvim rework  
**Primary host:** pluto (Hyprland + Wayland, Zen, Kitty, Neovim via `modules/desktop/home/nixvim.nix`, Obsidian on host today)

### Goal

Keyboard-centric writing: fast **word-level** completion (not aggressive whole-symbol LSP), good **grammar/spelling flow** for prose, Markdown vault workflow without Obsidian’s mouse-heavy UI, and **some** assistance in arbitrary app text fields (browser, forms). Explicitly **not** vim motions everywhere and **not** expecting games or every Electron app to participate.

### Reality check (accepted constraints)

Linux does **not** offer one daemon that replaces Neovim plugins, browser fields, and code LSP everywhere.

| Layer | What it can do | Where it breaks |
|-------|----------------|-----------------|
| **IBus + ibus-typing-booster** (IME) | Word prediction, hunspell, learned vocabulary in many GTK/Qt/browser fields | Hyprland needs deliberate IBus/Wayland setup; uneven in terminals, some Electron, games; Wayland preedit/inline completion UX is weaker than X11 (see upstream typing-booster docs) |
| **Neovim (cmp, ltex, obsidian.nvim)** | Full control in editor; grammar via **ltex-ls**; vault wikilinks in plain Markdown | Does not automatically apply outside Neovim |
| **Optional Espanso / expansions** | Boilerplate snippets | Not “smart” word finish or grammar |

**Neovim vs IME:** Running typing-booster **inside** Neovim insert mode while **nvim-cmp** is active causes double-completion friction. Planned approach: **one owner per zone** — Neovim uses cmp/ltex; other apps use IME when toggled on.

**Neovim LSP vs “word complete”:** Today nixvim prioritizes `nvim_lsp` in cmp with preselect, which feels like unwanted symbol completion (e.g. premature API suggestions). That is a **nixvim tuning** problem, not something typing-booster fixes. Prose (markdown) should likely use buffer/path sources only; code keeps LSP with stricter preselect/Tab behavior.

### Target architecture (three zones)

1. **Neovim** — notes + code: obsidian.nvim (or maintained fork) on existing vault, render-markdown.nvim for readability, ltex-ls for markdown/plaintext grammar; cmp profiles split by filetype.
2. **Non-Neovim text** — IBus + typing-booster pilot (Zen, forms, etc.); input source toggle (e.g. US keyboard vs “English (typing booster)”) so Neovim stays on plain layout during editing sessions.
3. **Optional** — Espanso or typing-booster expansions for static templates.

### Implementation phases (when rework starts)

**Phase 1 — Neovim only (no IBus yet)**  
Highest value, lowest integration risk.

- [ ] Markdown/plaintext cmp: `buffer`, `path`; disable or deprioritize LSP on prose filetypes
- [ ] Adjust preselect / Tab so LSP does not auto-confirm on minimal context
- [ ] obsidian.nvim + vault path; evaluate dropping or sidelining Obsidian desktop app
- [ ] ltex-ls + LanguageTool for grammar diagnostics on prose buffers
- [ ] Document daily workflow (vault path, Syncthing unchanged)

**Phase 2 — Desktop IME (Hyprland)**  
Only after Phase 1 is stable.

- [ ] NixOS module or host fragment: IBus ≥ 1.5.32, `ibus start --type wayland`, typing-booster engine
- [ ] Hyprland/env: follow current IBus + Hyprland guidance (avoid conflicting `GTK_IM_MODULE` / `QT_IM_MODULE` on native Wayland apps where docs say not to)
- [ ] AT-SPI env for Firefox/Zen/Qt if needed for per-app tuning (see typing-booster user docs)
- [ ] Operator doc: when to toggle input source (Neovim vs browser)
- [ ] App smoke test matrix: Zen, Kitty (terminal IME often weak), Zed, any retained Electron apps

**Phase 3 — Grammar outside Neovim (optional)**  
- [ ] LanguageTool browser extension or “paste into ltex buffer” workflow for long web forms

### Open decisions

- **IBus vs Fcitx 5** on Hyprland — pick one after a short pilot; some users report fewer edge cases with Fcitx; nebula currently configures neither.
- **obsidian.nvim** vs **obsidian-nvim/obsidian.nvim** fork — choose one maintained line before wiring.
- **Keep Obsidian desktop** for graph/preview only vs remove from `hosts/pluto/configuration.nix` once Neovim workflow sticks.
- **Nix placement:** extend `modules/desktop` vs new `modules/input` vs host-only on pluto until patterns stabilize.

### References (external)

- [ibus-typing-booster user docs](https://mike-fabian.github.io/ibus-typing-booster/docs/user/) (Wayland limitations section is required reading)
- [IBus 1.5.32 / Wayland IM v2](https://fedoraproject.org/wiki/Changes/IBus_1.5.32) (Hyprland relevance)
- obsidian.nvim ecosystem (vault-local Markdown, wikilinks)
- ltex-ls + nvim-lspconfig for LanguageTool in-editor

### Internal touchpoints

- Neovim: `modules/desktop/home/nixvim.nix` (cmp, LSP, future ltex/obsidian plugins)
- Desktop session: `modules/desktop/system/hyprland.nix`, `modules/desktop/themes/nebula/compositor/hyprland.conf`
- Browser: `modules/web-utils` (Zen default)
- Host packages: `hosts/pluto/configuration.nix` (Obsidian today)

---

## Desktop command palette (Obsidian-style)

**Status:** `idea` — same desktop rework as writing workflow; design after launcher cleanup  
**Primary host:** pluto (Hyprland + Wayland)

### Goal

One keyboard-driven **command palette** for the whole session: fuzzy find and run **commands**, not just launch apps — similar to Obsidian’s palette (Ctrl/Cmd+P) or VS Code’s command palette. Typo-tolerant matching, recents/frecency, and a small set of **common actions** without hunting menus or remembering every Hyprland bind.

Examples of what should be invokable from the same UI:

- Launch or focus apps (overlap with today’s launcher)
- Hyprland / session actions (workspace, move window, toggle float, lock, logout)
- Host-specific scripts (sync, deploy snippet, open vault daily note, screenshot)
- Future note actions (open wikilink target, search vault) once Neovim/vault integration exists
- Optional: calculator, emoji picker, clipboard history — only if they stay keyboard-first

### Today vs target

| Today | Limitation |
|-------|------------|
| **Fuzzel** on `Super+R` (`modules/desktop/home/fuzzel.nix`, `hyprland.conf`) | Primarily **application launcher** (drun); not a unified command registry with fuzzy command IDs and “did you mean …?” |
| Scattered **Hyprland binds** | Powerful but unsearchable; easy to forget |
| **Obsidian** palette | Rich inside Obsidian only; not system-wide |

Target: **one primary palette binding** (may keep a separate minimal app launcher or merge both into modes — see open decisions).

### Design notes

- **Fuzzy + correction:** Use a launcher that supports fuzzy scoring (most Wayland launchers do) and/or alias tables (“sync” → `syncthing …`, “nt” → “open today’s note”). True spell-check correction is optional; fuzzy subsequence match is the baseline.
- **Declarative commands in Nix:** Prefer generating palette entries from nebula (home-manager or a small `commands.json` / script registry) so fleet and pluto overrides stay reproducible — not a one-off `~/.config` only on one machine.
- **Wayland-native:** Must work on Hyprland without X11-only assumptions; test Electron (Zen, Obsidian) focus behavior when palette closes.
- **Do not duplicate Neovim’s palette** inside Neovim for editing commands — Neovim keeps `:Telescope`, `which-key`, etc. This feature is for **desktop / cross-app** actions; optional shallow bridge (“open Neovim on vault file X”) is enough.

### Candidate directions (pick during rework)

Evaluate during spike; no decision yet.

1. **Extend Fuzzel** — custom modes or wrapper script feeding non-.desktop actions into the same UI (lowest new dependency count if sufficient).
2. **Dedicated palette** — e.g. Walker, Anyrun, Ulauncher (Wayland builds), or rofi-wayland with a scripted command list — if Fuzzel cannot express commands + apps in one flow.
3. **Hyprland + small CLI** — palette invokes `hyprctl`, `playerctl`, `brightnessctl`, custom scripts; keep logic in versioned scripts under `hosts/pluto/` or a future `modules/desktop` fragment.

### Implementation phases (when rework starts)

**Phase 0 — Hygiene**  
- [ ] Fix duplicate `$mainMod+R` fuzzel bind (`docs/issues.md` #19) before adding a second palette key

**Phase 1 — Command registry**  
- [ ] Define a minimal schema: `{ id, label, keywords, exec }` checked into repo  
- [ ] Ship ~10–20 common pluto actions (lock, terminal, browser, file manager, audio, workspace jump)  
- [ ] Single default binding (e.g. `Super+P` palette, `Super+R` apps — or one surface with prefixes)

**Phase 2 — Integration**  
- [ ] Wire palette via home-manager desktop module; nebula theme colours consistent with fuzzel  
- [ ] Optional: integrate with note workflow (daily note, vault search) when Neovim/vault work from section above lands

**Phase 3 — Polish**  
- [ ] Frecency / usage ranking if the chosen tool supports it  
- [ ] Document binds in `docs/modules/desktop.md`

### Open decisions

- **One key vs two:** Single palette with “app mode” vs separate app launcher and command palette.
- **Tool choice:** Fuzzel-only vs Walker/Anyrun/other — spike on Hyprland with Zen + Kitty focused.
- **Nix home:** extend `modules/desktop/home/fuzzel.nix` vs new `home/command-palette.nix` fragment.
- **Testbed:** Same binds as pluto or reduced set for laptop role.

### Internal touchpoints

- Launcher today: `modules/desktop/home/fuzzel.nix`, `modules/desktop/themes/nebula/compositor/hyprland.conf` (`$menu`, `Super+R`)
- Binds and session: `modules/desktop/system/hyprland.nix`
- Host overrides: `hosts/pluto/configuration.nix`

---

## Template for new entries

```markdown
## Short title

**Status:** idea | design | ready  
**Primary host(s):** …

### Goal
…

### Notes / constraints
…

### Tasks
- [ ] …
```
