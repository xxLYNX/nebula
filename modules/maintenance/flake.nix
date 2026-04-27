{
  description = "Maintenance module: Nix store verification/repair, daemon DB backup, narinfo TTL hardening";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }: {

    nixosModules.default = { config, pkgs, lib, ... }:
    let
      cfg = config.services.maintenance;
    in {

      # ── Options ─────────────────────────────────────────────────────────────
      options.services.maintenance = {
        enable = lib.mkOption {
          type    = lib.types.bool;
          default = true;
          description = "Master switch for all nebula maintenance jobs.";
        };

        nixRepair = {
          enable = lib.mkOption {
            type    = lib.types.bool;
            default = true;
            description = ''
              Weekly nix-store --verify --check-contents --repair job.
              Re-downloads any store path whose hash doesn't match the expected hash.
              Addresses the daemon-level store corruption that manual ~/.cache/nix/ deletion cannot fix.
            '';
          };
          schedule = lib.mkOption {
            type    = lib.types.str;
            default = "weekly";
            description = "Systemd calendar expression for the repair job (e.g. 'weekly', 'Sun 03:00').";
          };
        };

        nixDbBackup = {
          enable = lib.mkOption {
            type    = lib.types.bool;
            default = true;
            description = ''
              Periodic backup of /nix/var/nix/db/db.sqlite via SQLite's online backup API.
              This is the daemon-owned registration database. When it is corrupted there is
              no built-in Nix recovery path — a recent backup is the only way to restore
              without a full reinstall.
            '';
          };
          dest = lib.mkOption {
            type    = lib.types.str;
            default = "/var/backup/nix-db";
            description = "Directory to write timestamped .sqlite backup files into.";
          };
          keep = lib.mkOption {
            type    = lib.types.int;
            default = 7;
            description = "Number of most-recent backups to retain (older ones are pruned).";
          };
          schedule = lib.mkOption {
            type    = lib.types.str;
            default = "daily";
            description = "Systemd calendar expression for the backup job.";
          };
        };

        narinfoTtl = {
          enable = lib.mkOption {
            type    = lib.types.bool;
            default = true;
            description = ''
              Reduce narinfo cache TTLs so poisoned entries expire quickly rather than
              persisting for the default 30-day positive TTL.
            '';
          };
          positiveTtl = lib.mkOption {
            type    = lib.types.int;
            default = 3600;
            description = "Seconds to cache a positive narinfo hit (default Nix: 2592000 / 30 days).";
          };
          negativeTtl = lib.mkOption {
            type    = lib.types.int;
            default = 0;
            description = "Seconds to cache a negative narinfo result. 0 = always re-check.";
          };
        };
      };

      # ── Implementation ───────────────────────────────────────────────────────
      config = lib.mkIf cfg.enable {

        # ── narinfo TTL hardening ──────────────────────────────────────────────
        nix.settings = lib.mkIf cfg.narinfoTtl.enable {
          narinfo-cache-positive-ttl = cfg.narinfoTtl.positiveTtl;
          narinfo-cache-negative-ttl = cfg.narinfoTtl.negativeTtl;
        };

        # ── Nix store repair ──────────────────────────────────────────────────
        # nix-store --verify --check-contents --repair re-fetches any store path
        # whose content hash doesn't match the expected hash in the daemon DB.
        # This is the correct recovery tool for incomplete-download corruption.
        systemd.services.nix-store-repair = lib.mkIf cfg.nixRepair.enable {
          description = "Nix store integrity check and repair";
          serviceConfig = {
            Type            = "oneshot";
            # Must run as root — the Nix daemon owns /nix/var/nix/db/
            User            = "root";
            # Give it plenty of time; large stores can take a while.
            TimeoutStartSec = "6h";
            # Low I/O priority so it doesn't disrupt interactive use.
            IOSchedulingClass = "idle";
            CPUSchedulingPolicy = "idle";
            ExecStart = "${pkgs.nix}/bin/nix-store --verify --check-contents --repair";
          };
          # Don't block boot if it fails; this is a background health job.
          unitConfig.IgnoreOnIsolate = true;
        };

        systemd.timers.nix-store-repair = lib.mkIf cfg.nixRepair.enable {
          description = "Weekly Nix store integrity check";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar         = cfg.nixRepair.schedule;
            Persistent         = true;  # run on next boot if a scheduled run was missed
            RandomizedDelaySec = "2h";  # spread load across a fleet
          };
        };

        # ── Daemon DB backup ──────────────────────────────────────────────────
        # /nix/var/nix/db/db.sqlite is the Nix daemon's store registration database.
        # SQLite's .backup command uses the online backup API — consistent snapshot
        # even while the daemon is actively writing, no daemon shutdown required.
        systemd.services.nix-db-backup = lib.mkIf cfg.nixDbBackup.enable {
          description = "Backup Nix daemon store database";
          serviceConfig = {
            Type  = "oneshot";
            User  = "root";
            ExecStart = pkgs.writeShellScript "nix-db-backup" ''
              set -euo pipefail
              dest="${cfg.nixDbBackup.dest}"
              keep="${builtins.toString cfg.nixDbBackup.keep}"
              src="/nix/var/nix/db/db.sqlite"
              mkdir -p "$dest"
              stamp=$(date -u +"%Y%m%dT%H%M%SZ")
              out="$dest/db-$stamp.sqlite"
              # SQLite online backup API — safe on a live, write-active database.
              ${pkgs.sqlite}/bin/sqlite3 "$src" ".backup '$out'"
              echo "nix-db-backup: wrote $out"
              # Prune oldest backups, keeping only the $keep most recent.
              ls -1t "$dest"/db-*.sqlite 2>/dev/null | tail -n +"$((keep + 1))" | xargs -r rm -f --
              echo "nix-db-backup: retained $(ls -1 "$dest"/db-*.sqlite | wc -l) backups"
            '';
          };
          unitConfig.IgnoreOnIsolate = true;
        };

        systemd.timers.nix-db-backup = lib.mkIf cfg.nixDbBackup.enable {
          description = "Periodic Nix daemon DB backup";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar         = cfg.nixDbBackup.schedule;
            Persistent         = true;
            RandomizedDelaySec = "30m";
          };
        };

        # Ensure sqlite3 is available for the backup script.
        environment.systemPackages = lib.mkIf cfg.nixDbBackup.enable [ pkgs.sqlite ];
      };
    };

  };
}
