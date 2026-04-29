# nebula

Single source of truth for all NixOS machines. Every host is described once — in `inventory/machines.json` — and the flake builds its full system config from that entry plus its assigned role and modules. Adding a machine, changing a package, or rotating a secret is a single commit that propagates to the whole fleet on the next deploy.

---

## Repo structure

```
flake.nix                  # Root flake. Reads inventory, builds nixosConfigurations + colmena.
flake.lock                 # Pinned inputs. Commit after any `nix flake update`.
inventory/machines.json    # Single source of truth: one entry per machine.
hosts/<name>/              # Per-host config (hardware facts, host-specific overrides).
roles/<name>/              # Role flakes — compose modules into a machine personality.
modules/                   # Composable feature modules (desktop, web-utils, …).
docs/                      # Operator runbooks and migration tracking.
terraform/                 # One-shot provisioner for new machines (nixos-anywhere).
```

---

## About the stack

### NixOS — the operating system
NixOS is a Linux distribution where the entire system — packages, services, users, kernel parameters — is declared in Nix code and built atomically. There is no imperative `apt install` or config file edited in place. Every rebuild produces a new system generation that can be rolled back in the boot menu. This makes machines reproducible: the same config always produces the same system, on any hardware.

### home-manager — user environment management
home-manager extends NixOS's declarative model into the user's home directory. Dotfiles, shell config, application settings, and user services are all declared in Nix and applied atomically alongside the system. In nebula it is integrated as a NixOS module (not run as a standalone tool), so `colmena apply-local` rebuilds both the system and the user environment in one step with no separate `home-manager switch`.

### disko — declarative disk partitioning
Traditional NixOS installs require manually running `parted`/`fdisk` before install, then `nixos-generate-config` detects what you created. Disko replaces this: the partition layout is declared in Nix, version-controlled in the repo, and executed once during bootstrap from the live ISO. The result is that a machine's full disk layout — partition table, filesystem types, swap — is reproducible from the repo rather than from someone's memory of what commands they ran.

### Colmena — fleet deployment
`nixos-rebuild switch` applies a config to the machine you are sitting on. Colmena inverts this: the config lives in a central repo and Colmena pushes outward to the fleet over SSH. It adds multi-host orchestration, tag-based targeting, and deployment metadata on top of standard NixOS evaluation — but the underlying system management is identical. `colmena apply-local` is just `nixos-rebuild` reading from the `colmenaHive` flake output rather than `/etc/nixos`.

---

## Tools and their roles

### Colmena — ongoing fleet deployments
Colmena is the primary deployment tool. It reads the `colmena` output from `flake.nix` and SSH-deploys to all machines defined in the inventory.

```bash
# Deploy to all machines in the fleet
colmena apply

# Deploy to a specific machine by name
colmena apply --on testbed

# Deploy to all machines with a given tag (tags set in inventory)
colmena apply --on @testing

# Deploy from the machine itself (no remote Nix host needed)
# Run this from inside the repo directory on the target machine
colmena apply-local --sudo
```

`colmena apply-local --sudo` is the standard self-deploy command. It does not take a `--flake` flag — colmena detects the flake automatically when run from the repo root.

**Normal update cycle on a managed machine:**
```bash
cd ~/nebula
git pull
colmena apply-local --sudo
```

**Intentional input bump** (when you want newer packages from nixpkgs):
```bash
nix flake update
git add flake.lock && git commit -m "chore: update flake inputs" && git push
colmena apply-local --sudo
```

### Terraform — one-shot provisioner
Terraform is only used to bring a *new* machine into existence. It calls `nixos-anywhere` to partition, install, and reboot the target. Once the machine is running NixOS, Terraform is no longer involved — Colmena takes over.

```bash
# From a machine with Terraform installed (Linux/macOS; Windows requires WSL)
cd terraform
terraform init
terraform apply \
  -var="target_host=<live-iso-ip>" \
  -var="install_ssh_key=$(cat ~/.ssh/id_ed25519)"
```

For bare-metal machines where nixos-anywhere is impractical, use the manual ISO flow documented in `docs/BOOTSTRAP.md`.

### Ansible
Not currently in use. Intended future role: bootstrapping pre-NixOS machines (installing Nix, cloning this repo, running the first `colmena apply-local`) where you can't boot a NixOS ISO directly. Ansible handles the *transition*, Colmena handles everything after.

---

## Adding a new machine

1. Add an entry to `inventory/machines.json`:
   ```json
   "myhostname": {
     "hostname": "myhostname",
     "primaryUser": "username",
     "platform": "linux",
     "role": "testing",
     "packs": ["testing", "web-utils"],
     "tags": ["testing"],
     "swapSize": "8G",
     "diskDevice": "/dev/sda",
     "deployTarget": "myhostname"
   }
   ```
2. Create `hosts/myhostname/configuration.nix` (import hardware config, add host-specific overrides).
3. Create `hosts/myhostname/hardware-configuration.nix` (run `nixos-generate-config` on the target and copy output here).
4. Bootstrap: boot to NixOS live ISO, run `nixos-install` per `docs/BOOTSTRAP.md`, or use Terraform.
5. Once online: `colmena apply --on myhostname`.

---

## Pending migration

See `docs/pending.md` for a full checklist of software and settings from the previous `pluto-config` not yet ported to nebula modules.
