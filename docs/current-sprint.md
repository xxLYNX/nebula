# Current Sprint — Nebula Fleet Review

Captured from project review (2026-09-04). Use this as the working backlog for the current sprint.

---

## Executive Summary

| Goal | Current State | Verdict |
|------|---------------|---------|
| Fleet management | Inventory + Colmena + enrollment script, 2 hosts | **Good foundation, small fleet** |
| Strong security posture | SOPS + role-based SSH hardening; security module unused | **Partial — lab vs prod split is intentional but uneven** |
| SBOM | CLI TODO + architecture doc only | **Not implemented** |
| Package update visibility | Pinned `flake.lock`, manual workflow | **Minimal — no tracking or CVE correlation** |
| Software inventory / provenance | No automated closure report until this sprint | **Gap — see dedicated section below** |
| Rollback broken updates | NixOS generations (boot menu, 30-gen limit) | **Native only — no fleet orchestration** |

**Bottom line:** Nebula is a well-structured homelab/small-fleet CM system mid-migration from a prior config. It is **not yet** the security-aware fleet platform the architecture doc describes — but the bones are right, and NixOS already gives you rollback and reproducibility for free if you operationalize them.

---

## What's Working Well

### 1. Inventory-driven composition is the right model

`inventory/machines.json` is the single source of truth, and `flake.nix` turns each entry into a full host via roles + registry modules. The registry pattern (`modules/registry/flake.nix`) means new capabilities don't require editing the root flake every time.

### 2. Secrets and enrollment are thoughtfully designed

The enrollment marker pattern in `flake.nix` avoids sops-nix evaluating missing secret files on unenrolled hosts. `scripts/enroll-machine.sh` is production-quality: auto-bootstraps tools, defensive checks, password hashing, age key from host SSH key.

**Enrollment SSOT (fixed this sprint):** `secrets/machines/<hostname>/enrolled` marker file only. Inventory must not duplicate an `enrolled` field — the flake ignores it.

### 3. Role separation reflects real intent

- **Pluto** (workstation): SSH key-only, no root login, sudo requires password.
- **Testbed**: deliberately weak for lab use — passwordless sudo, open SSH — documented and acceptable only if isolated.

### 4. Maintenance module shows operational maturity

Store repair, SQLite DB backup, narinfo TTL hardening — incident-driven engineering, not boilerplate.

### 5. Self-awareness in `docs/issues.md`

500+ lines of design debt with file references. Most reviewers would have to discover enable-flag inconsistency, role duplication, and schema drift themselves.

---

## Gaps vs Stated Goals

### SBOM — essentially zero implementation

CLI `validate` is a stub (`// TODO: call nix eval + vulnix + sbom`). Architecture doc describes Trivy + SBOM + nix audit → Wazuh/Kyverno; none of that exists in CI or modules.

**What's missing for SBOM on NixOS:**

- Per-generation SBOM from `nix path-info --json` on each host toplevel
- CVE scanning via `vulnix` or `nix audit` against pinned nixpkgs
- Flake input provenance recorded on every build (git SHA + lock metadata)
- Artifact storage — SBOMs tied to commit, not ephemeral console output

Nix gives a stronger SBOM story than most distros *if you capture it* — every closure is content-addressed and reproducible.

### Package update tracking — manual and opaque

Today: `nix flake update` → commit `flake.lock` → `colmena apply`.

Missing:

- Automated flake update MRs
- Per-host drift detection (shared lockfile helps consistency but doesn't log "what landed where")
- `system.autoUpgrade` (in `docs/pending.md`)
- CVE correlation with flake bumps

For "know when and what packages are updated," you need **git history of `flake.lock` + deploy audit trail**, not just the lockfile.

### Rollback — Nix-native only, not fleet-operational

Configured: `systemd-boot` with 30 generations and 5s boot menu timeout.

Missing:

- Fleet rollback playbook
- Colmena wrapper for remote rollback by tag
- Health check + auto-rollback on failed activation
- Pre-deploy generation pinning until smoke test passes

### Security posture — foundation without enforcement layer

| Layer | Status |
|-------|--------|
| SOPS + host-key age identity | Implemented (pluto enrolled) |
| SSH hardening by role | pluto role |
| `security-host` module | Exists, **not on any host** |
| Supply-chain gates in CI | Not implemented |
| Monitoring (Wazuh, Falco, etc.) | Architecture only |
| Management secrets threshold | Single age recipient until YubiKey |

---

## Software Inventory and Provenance (Expanded)

This was under-emphasized in the initial review. Nix does **not** automatically solve "what is installed and where did it come from?" — it solves **reproducible builds** if you declare everything in Nix. You still inherit the same trust problems as other distros if you don't instrument them.

### The blind trust problem

1. **You trust nixpkgs maintainers** — every `pkgs.foo` is a recipe someone wrote; you're not verifying upstream source tarballs yourself unless you audit derivations.
2. **You trust flake inputs** — community flakes (zen-browser, colmena, etc.) pin to their own upstreams; a compromised input flows into your closure silently.
3. **You trust the binary cache** — substituters can serve pre-built paths; Nix verifies narHash, but you're still trusting whoever populated the cache matched the derivation.
4. **Declarative ≠ visible** — packages spread across role flakes, registry modules, host overrides, and home-manager. No single `dpkg -l` equivalent unless you generate it.

### The outdated nixpkgs problem

Root flake pins nixpkgs to a specific commit (`flake.lock`). That is good for reproducibility but bad for freshness:

- Security patches land in nixpkgs continuously; a pinned commit ages immediately.
- Many packages lag upstream by weeks or months — normal for a rolling distro snapshot, painful when you need a specific CVE fix or app version.
- `nix flake update` is a blunt instrument: bumps everything, hard to review, no per-package policy.

**Mitigations to adopt (sprint + next):**

| Approach | Purpose |
|----------|---------|
| `scripts/closures-report.sh` | Enumerate each host's system closure + flake input revs (added this sprint) |
| CI artifact: closure JSON per host per commit | Historical "what was installed when" |
| Pin critical apps via **dedicated flake inputs** (already done for zen-browser) | Fresher versions without waiting for nixpkgs |
| **Overlays** for one-off version bumps | e.g. `firefox = super.firefox.overrideAttrs ...` |
| **`nix-prefetch-url` / vendorHash bumps** for custom packages | Full control when you package yourself |
| Scheduled flake update MR with **diff summary** | Human-readable "what changed" before apply |
| **`vulnix` / `nix audit` in CI** | Known CVEs against pinned nixpkgs |
| Document **staleness policy** | e.g. "nixpkgs pin ≤ 14 days old on pluto" |

### What "know what's installed" should look like

Minimum viable fleet software visibility:

```bash
# From repo root — closure + flake provenance
./scripts/closures-report.sh
./scripts/closures-report.sh --json pluto > artifacts/pluto-closure.json
```

Target state (not yet built):

1. **Build time:** CI builds each host toplevel, emits closure JSON + flake metadata as artifacts.
2. **Deploy time:** Post-`colmena apply` hook records generation ID + git rev on each host.
3. **Compare time:** Diff closures between commits to answer "what packages changed in this deploy?"
4. **Audit time:** Cross-reference closure with CVE DB; flag packages older than upstream release policy.

---

## Structural Issues That Will Bite You

Status after this sprint's fixes:

| Issue | Status | Fix |
|-------|--------|-----|
| CI out of sync with inventory schema | **Fixed** | `.gitlab-ci.yml` uses `os.role`, `users.admin`, `roles/**/*` |
| Enrollment signal split (marker vs inventory) | **Fixed** | Marker file only; removed `enrolled` from inventory; updated enroll script + secrets README |
| Go CLI non-compiling | **Fixed** | Added `package` declarations, `version.go`, viper import; run `go mod tidy` locally to generate `go.sum` |
| Role duplication (testing ≈ pluto) | **Fixed** | Extracted `roles/common/base.nix` for shared disko/boot/avahi |
| Module enable flags vs inventory | **Fixed** | `flake.nix` sets `services.*.enable` from `os.modules` list |

### Remaining follow-ups from structural work

- Run `cd cli && go mod tidy && go build ./...` on a machine with working Go module proxy; commit `go.sum`.
- Decide whether to track `cli/` in git this sprint or next (currently untracked).
- CI `validate:inventory-policy` allowlist must be updated when adding roles/modules.

---

## Architecture Assessment

```
Implemented          Partial              Design only
─────────────        ───────              ───────────
inventory ──► flake  GitLab CI (fixed)    Trivy / vulnix / SBOM
     │               security-host        Wazuh / Falco
     ▼               Go CLI (WIP)         RBAC / deploy policy
  Colmena
  SOPS enroll
  Modules
```

You are solidly in the **left column**. The architecture doc describes the **right column**. The gap is incremental — you don't need Kubernetes, Keycloak, and Kyverno to get SBOM, software inventory, and rollback working on a 2-host Nix fleet.

---

## Prioritized Recommendations

### Tier 1 — Fix trust in what you have (low effort, high value)

1. ~~Align CI with current inventory schema~~ **Done**
2. ~~Pick one enrollment signal~~ **Done**
3. Enroll testbed or isolate it — placeholder age key + open SSH is fine for disconnected lab only

### Tier 2 — Deliver SBOM + update + software visibility (core ask)

4. **Wire `closures-report.sh` into CI** — artifact per host per commit
5. Add CI job: `vulnix` or `nix audit` — start as allow_failure, tighten later
6. Flake update bot — weekly MR with lock diff summary
7. Post-deploy generation audit — record git rev + generation on each host

Example CI direction:

```bash
nix build ".#nixosConfigurations.pluto.config.system.build.toplevel" --no-link
./scripts/closures-report.sh --json pluto > sbom-pluto-${CI_COMMIT_SHA}.json
```

### Tier 3 — Operational rollback (fleet-scale)

8. Write rollback runbook: local `nixos-rebuild switch --rollback`, remote `colmena exec`, boot menu
9. Pre-deploy smoke test + auto-rollback script on failure
10. Generation audit log (JSON in repo or external store)

### Tier 4 — Security posture (when fleet grows)

11. Add `security-host` to pluto inventory modules (not testbed)
12. YubiKey / threshold for management secrets
13. Finish CLI `validate` wrapping CI checks + vulnix

---

## What Not To Do Yet

- Don't deploy full Wazuh/Falco/Suricata/K8s stack until SBOM + rollback + CI are solid on 2 hosts
- Don't add Ansible unless non-NixOS machines are imminent
- Don't over-invest in Go CLI until bash + CI + colmena wrappers cover 80% of ops

---

## Sprint Checklist

Use this as the active task list:

- [x] Create `docs/current-sprint.md`
- [x] Fix CI inventory schema drift
- [x] Unify enrollment on marker file
- [x] Extract `roles/common/base.nix`
- [x] Wire `os.modules` → module enable flags
- [x] Fix CLI compile structure + add `closures-report.sh`
- [x] Run `go mod tidy` in `cli/` and commit `go.sum`
- [x] Verify flake check + builds + colmena apply-local (2026-09-05, pluto)
- [ ] Add CI job for closure report artifacts
- [ ] Add `vulnix` / `nix audit` CI job
- [ ] Write rollback runbook in `docs/`
- [ ] Enroll or network-isolate testbed
- [ ] Add `security-host` to pluto when ready

---

## Final Opinion

Nebula is **better than most personal fleet repos**: clear SSOT, modular flakes, real secrets story, honest documentation of debt.

| Area | Assessment |
|------|------------|
| Fleet management | ~70% for small NixOS fleet; Colmena + inventory is the right choice |
| Security posture | Strong config security; weak supply-chain and runtime security |
| SBOM | Aspirational — Nix makes it easier once CI captures closures |
| Update tracking | Implicit in git, not explicit in tooling |
| Software inventory | Starting point: `scripts/closures-report.sh`; needs CI integration |
| Rollback | Nix provides mechanism; need procedure and automation |

Highest-leverage next step after structural fixes: **CI closure artifacts + vulnix**, then **rollback runbook**.

---

## Verification Run (2026-09-05)

Full validation performed on **pluto** after sprint changes + `nix flake update`:

| Check | Result |
|-------|--------|
| `nix flake check --no-build` | Pass (pre- and post-update) |
| Build `nixosConfigurations.pluto` | Pass |
| Build `nixosConfigurations.testbed` | Pass |
| `scripts/ci-validate-inventory.sh` | Pass |
| `services.gaming.enable` (inventory-driven) | `true` on pluto and testbed |
| `users.mutableUsers` on pluto (enrolled) | `false` |
| `sops.defaultSopsFile` on pluto | Set to encrypted `machine.yaml` |
| `colmena apply-local --sudo` on pluto | **Activation successful** |
| SOPS runtime secret | `/run/secrets-for-users/user_password_hash` present |
| Go CLI build | Pass (`nebula dev`) |
| `scripts/closures-report.sh pluto` | Pass |

**Bug found and fixed during verification:** Setting `services.securityHost.enable = lib.mkIf false` still references undefined options when the module isn't imported. Fixed by conditionally importing enable-only config fragments only for modules listed in inventory.

**Warnings to address later (non-blocking):**

- Home Manager 26.11 vs Nixpkgs 26.05 version mismatch
- `home.pointerCursor` deprecation warning
- nixpkgs pin unchanged by `flake update` (root flake pins explicit rev; update refreshed transitive inputs like zen-browser, sops-nix, colmena)

**To deploy testbed:** run `colmena apply --on testbed` or `colmena apply-local --sudo` from testbed after committing/pushing these changes.
