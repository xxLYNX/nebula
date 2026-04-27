# maintenance module

**Location:** `modules/maintenance/flake.nix`  
**Pack name:** `maintenance`  
**Options namespace:** `services.maintenance`

---

## Why this module exists

### The bug

There is a long-standing Nix bug (open since at least 2021) where an interrupted package download can corrupt the local Nix installation in a way that is very difficult to recover from. The failure mode is:

1. A substituter download stalls or is interrupted mid-transfer.
2. A partial store path lands in `/nix/store/` and gets registered in the Nix daemon's store database at `/nix/var/nix/db/db.sqlite` as if it were complete.
3. Because the daemon owns that database, subsequent builds see the path as already present and skip re-downloading it.
4. Every operation that depends on that path fails with a hash mismatch or missing file error.

The commonly suggested manual fix — deleting `~/.cache/nix/` to clear the per-user narinfo cache — **does not work** for this failure mode. The narinfo cache only records which paths are *available on substituters*. The actual corruption is in the daemon-level SQLite database, which is not touched by that fix. At that point, without a backup of the DB, the only path forward is a full reinstall.

There is also a secondary failure mode: the daemon database uses SQLite WAL (write-ahead log) mode. If the Nix daemon is killed during a write (power loss, OOM kill, etc.) the WAL file can be left in an inconsistent state, which is a separate but similarly destructive corruption.

This module was created after exactly this scenario caused the loss of a working NixOS machine.

---

## What the module does

Three independent subsystems, all enabled by default:

### 1. Nix store repair (`services.maintenance.nixRepair`)

Runs `nix-store --verify --check-contents --repair` on a schedule (default: weekly).

This is the correct recovery tool for incomplete-download corruption. It:
- Walks every registered store path.
- Recomputes the content hash of each path on disk.
- Re-downloads any path whose hash doesn't match the expected value recorded in the daemon DB.

This operates at the daemon level and would have repaired the corruption described above automatically, before it was noticed.

The timer uses `Persistent = true` so if the machine is off during a scheduled window, the job runs on next boot. It runs at idle I/O and CPU priority so it doesn't affect interactive use.

### 2. Daemon DB backup (`services.maintenance.nixDbBackup`)

Backs up `/nix/var/nix/db/db.sqlite` daily using SQLite's **online backup API** (`sqlite3 … .backup`).

This is important because:
- The daemon DB is owned by root and the Nix daemon process.
- There is no built-in Nix mechanism to back it up or restore it.
- Standard file copy is unsafe on a live database (can capture a torn write mid-transaction). The SQLite online backup API is explicitly designed for live, write-active databases and produces a consistent snapshot.

Backups are written to `/var/backup/nix-db/db-<timestamp>.sqlite`. The 7 most recent are kept; older ones are pruned automatically.

**Recovery procedure** if the daemon DB is corrupted and the repair job cannot fix it:
```bash
sudo systemctl stop nix-daemon
sudo cp /var/backup/nix-db/db-<most-recent-timestamp>.sqlite /nix/var/nix/db/db.sqlite
sudo systemctl start nix-daemon
```
Then run `nix-store --verify --check-contents --repair` to re-download any paths that existed after the backup was taken but are now missing.

### 3. Narinfo TTL hardening (`services.maintenance.narinfoTtl`)

Sets two `nix.settings` values:

| Setting | Default (Nix) | This module |
|---|---|---|
| `narinfo-cache-positive-ttl` | 2,592,000 s (30 days) | 3,600 s (1 hour) |
| `narinfo-cache-negative-ttl` | 3,600 s | 0 s (never cache) |

The narinfo cache (`~/.cache/nix/binary-cache-v*.sqlite`) records which store paths are available on substituters. If this cache is poisoned (e.g. a path is recorded as present on a substituter that no longer has it, or as absent when it has since been added), the reduced TTL ensures the bad entry expires within an hour rather than persisting for 30 days.

Setting the negative TTL to 0 means Nix never caches a "not found" result — it always re-checks. This is slightly more network traffic but eliminates an entire class of "why won't it download this path" failures.

---

## Options reference

```nix
services.maintenance = {
  enable = true;  # master switch

  nixRepair = {
    enable   = true;
    schedule = "weekly";  # any systemd OnCalendar expression
  };

  nixDbBackup = {
    enable   = true;
    dest     = "/var/backup/nix-db";
    keep     = 7;          # number of most-recent backups to retain
    schedule = "daily";
  };

  narinfoTtl = {
    enable      = true;
    positiveTtl = 3600;  # seconds
    negativeTtl = 0;     # 0 = never cache negative results
  };
};
```

All options default to safe/enabled values. Adding `maintenance` to a machine's `packs` in `inventory/machines.json` is all that is needed.

---

## What this does NOT protect against

- **Physical disk failure** — use off-machine backups for that.
- **`/nix/store/` content corruption without DB corruption** — the repair job handles hash mismatches, but if the SQLite DB itself is corrupted (not just containing wrong data), the DB backup is the only recovery path.
- **Corruption that happens between backup windows** — the daily backup means up to ~24 hours of exposure. Reduce `nixDbBackup.schedule` (e.g. `"*:0/6"` for every 6 hours) on machines with high package churn if that is a concern.
