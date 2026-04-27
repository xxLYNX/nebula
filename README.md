# nebula

Single source of truth for all NixOS machines. Every host is described once — in `inventory/machines.json` — and the flake builds its full system config from that entry plus its assigned role and modules. Adding a machine, changing a package, or rotating a secret is a single commit that propagates to the whole fleet on the next deploy.

---

## Repo structure

```
flake.nix                  # Root flake. Reads inventory, builds nixosConfigurations + colmena.
flake.lock                 # Pinned inputs. Commit after any `nix flake update`.
inventory/machines.json    # Single source of truth: one entry per machine.
hosts/<name>/              # Per-host config (hardware, host-specific overrides).
modules/                   # Composable feature modules (desktop, web-utils, …).
profiles/roles/            # Role flakes assigned to machines via inventory packs[].
docs/                      # Operator runbooks and migration tracking.
terraform/                 # One-shot provisioner for new machines (nixos-anywhere).
```

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
