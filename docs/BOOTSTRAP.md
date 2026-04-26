# BOOTSTRAP.md

This document describes the recommended bootstrap flow for bringing up a new machine using the monorepo's Colmena/NixOS flow and a local USB-based SOPS/age bootstrap. It covers repository layout expectations, preparing an encrypted USB containing private key material (temporary/local), and the step-by-step "first device" flow that uses the repo's Colmena flow locally. It also covers operational notes (key rotation, backups, CI considerations).

Goals
- Allow safe GitOps-style operations where encrypted secrets are stored in the repo, but private keys remain offline.
- Provide a simple, repeatable local-first bootstrap for the very first device.
- Keep Terraform for provisioning/orchestration and Colmena for NixOS deployments.
- Make role/modules composition reproducible and parameterized by `inventory`.

Assumptions
- You have a cloned copy of the monorepo on the operator machine or will clone it onto the target during the live-USB session.
- The repo contains:
  - `flake.nix` at repo root
  - `inventory/machines.json`
  - `nixosConfigurations` exported by the flake (via `nixosConfigurations.<host>`)
  - `secrets/` with SOPS-encrypted files (e.g., `.yaml.enc`) and public recipients recorded
  - `colmena` config exposed in the flake outputs (see `flake.nix`)
  - `modules/` with reusable packaged modules; `profiles/roles/` that compose `modules/`

Repository layout (relevant paths)
- `flake.nix` - root flake; exports `colmena` and `nixosConfigurations`.
- `inventory/machines.json` - single source-of-truth for host-level metadata (hostname, primaryUser, packs/modules, tags, diskDevice, swapSize, role, env).
- `profiles/roles/<role>/flake.nix` - role flakes which accept `_module.args` (top-level flake passes `primaryUser` and `machine`).
- `modules/*` - reusable modules which provide service wiring (e.g., `security-host`).
- `secrets/` - sops-encrypted files (public recipients are in repo, private keys are external).
- `docs/BOOTSTRAP.md` - this file.

Threat model & tradeoffs
- Storing encrypted secrets in git (SOPS/age) is safe so long as private keys are kept secret.
- USB with private age key is used as a bootstrap secret store. If the USB is lost or compromised, you must rotate recipients and re-encrypt secrets.
- Prefer hardware tokens (YubiKey) in the long term; the USB approach is a practical short-term bootstrap.

Preparation: generate age keypair (recommended)
- Generate an age keypair on a trusted machine and keep the public key in the repo. Keep the private key only on the encrypted USB (or hardware token).
- Example (illustrative):
```/dev/null/generate-age-key.sh#L1-20
# Generate an age keypair (age is installed)
age-keygen -o ./age_key.txt
# Save public recipient in the repo (commit only the public recipient)
grep -v '^#' age_key.txt | head -n1 > ./secrets/age_recipient.pub
# Keep age_key.txt (private) only on your secure USB (encrypted with LUKS) or hardware token.
```

Create an encrypted USB (LUKS) for private keys (recommended)
- Use LUKS to encrypt the USB. Keep the passphrase separate (memorize/store securely). Example (illustrative):
```/dev/null/luks-setup.sh#L1-40
# WARNING: adjust device path carefully!
USB_DEV=/dev/sdX
# Create LUKS container
sudo cryptsetup luksFormat $USB_DEV
# Open it
sudo cryptsetup luksOpen $USB_DEV secret-usb
# Make a filesystem
sudo mkfs.ext4 /dev/mapper/secret-usb
# Mount it
sudo mkdir -p /mnt/secret-usb
sudo mount /dev/mapper/secret-usb /mnt/secret-usb
# Copy the private key (done offline)
sudo cp ./age_key.txt /mnt/secret-usb/
sudo chmod 600 /mnt/secret-usb/age_key.txt
# Unmount and close
sudo umount /mnt/secret-usb
sudo cryptsetup luksClose secret-usb
```
- When you need the key: mount the LUKS USB, point SOPS/age at the private key, then decrypt files only for the build process.

SOPS / age usage (repo pattern)
- Store encrypted secrets in `secrets/`:
  - e.g., `secrets/db-creds.yaml.enc`, `secrets/restic.key.enc`
- Keep public recipients (age pubkeys) in `secrets/recipients.pub` or rely on SOPS metadata in each file.
- Minimal example: encrypt a YAML with an age recipient:
```/dev/null/sops-encrypt-example.sh#L1-20
RECIPIENT="$(cat secrets/age_recipient.pub)"
sops --encrypt --age "$RECIPIENT" secrets/example.yaml > secrets/example.yaml.enc
```

Where the private key is used
- Local-first flow: you will mount the USB and provide the private key to `sops` / `sops-nix` during `nix build` or when running `colmena` locally.
- CI: only add CI as a recipient if necessary for automated decrypts. Prefer having protected manual deploys for secrets-heavy steps.

Bootstrapping the first device (local Colmena flow)
This is the recommended flow to get a laptop up-to-date with the monorepo configuration for the first time.

High-level options
- Option A — Local-first (recommended for single-device bootstrap): boot the device, install minimal NixOS, clone the repo on the device, mount USB and run `colmena` locally or `nixos-rebuild switch`.
- Option B — Operator-driven (from your workstation): boot device, make it reachable via SSH, operator runs Terraform/`nixos-anywhere` or Colmena to push config remotely (must have the private key available to the operator at that time).

Detailed local-first steps (Option A)
1. Boot the target machine from a NixOS ISO (or use another installer flow).
2. Partition & format the disk. You can use `disko` in your flake, or manual commands. If using `disko`, you can generate the filesystem and then `nixos-install` into it. Example (manual minimal flow):
```/dev/null/manual-install-steps.sh#L1-40
# Boot from NixOS ISO, open shell
# Partition /dev/sda (example using parted)
sudo parted -s /dev/sda mklabel gpt
sudo parted -s /dev/sda mkpart primary 1MiB 513MiB
sudo parted -s /dev/sda mkpart primary 513MiB 100%
# Format: boot as FAT, root as ext4 or xfs
sudo mkfs.vfat -F32 /dev/sda1
sudo mkfs.xfs /dev/sda2
# Mount and install
sudo mount /dev/sda2 /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/sda1 /mnt/boot
# Copy a minimal config (or use your flake)
```
3. Install a minimal NixOS system if needed, or keep the live environment and operate directly from it.
4. Clone the repo on the device:
```/dev/null/clone-repo.sh#L1-4
git clone <your-repo-url> /root/repo
cd /root/repo
```
5. Mount the USB and expose the private key to SOPS/age:
```/dev/null/mount-usb-and-key.sh#L1-12
# Mount LUKS USB (example)
sudo cryptsetup luksOpen /dev/sdX secret-usb
sudo mount /dev/mapper/secret-usb /mnt/secret-usb
export SOPS_AGE_KEY_FILE=/mnt/secret-usb/age_key.txt
# Alternatively, copy to /root/.config/sops/age_key.txt with strict permissions
```
6. Verify you can decrypt a secret (sanity check):
```/dev/null/sops-decrypt-check.sh#L1-6
sops --decrypt ./secrets/example.yaml.enc > /tmp/example.yaml
# inspect, then securely delete
shred -u /tmp/example.yaml
```
7. Use Colmena locally to apply the host configuration from the repo:
   - Your root flake should export the `colmena` set. From the repo root:
```/dev/null/colmena-local-apply.sh#L1-12
# build colmena target for this host
nix build .#colmena.<YOUR_HOST>
# or run colmena directly if available
# Example: colmena apply -c ./colmena -p <profile> --no-ssh (local)
# If using nixos-rebuild directly:
sudo nixos-rebuild switch --flake .#nixosConfigurations.<this-host>
```
Notes:
- If your NixOS install expects secrets to be present at build time (e.g., sops-nix decrypt), ensure `SOPS_AGE_KEY_FILE` or appropriate environment is set for `nix build`.
- Keep decrypted artifacts in tmpfs and remove them after the build completes.

Operator-driven remote flow (recommended for testbed / first provisioning)
- Boot the target machine from a NixOS live ISO.
- On the live ISO:
  ```bash
  # Set a temporary root password
  passwd
  # Open firewall so SSH is reachable
  systemctl stop firewall   # or: iptables -I INPUT -p tcp --dport 22 -j ACCEPT
  # Start sshd
  systemctl start sshd
  # Note the IP
  ip addr
  ```
- From your operator machine (Windows / Linux / macOS), copy your SSH public key:
  ```powershell
  # PowerShell (Windows)
  type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh root@<TARGET_IP> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
  ```
- Still on the live ISO (SSH'd in or at the console), run nixos-anywhere to partition, install, and reboot:
  ```bash
  nix --extra-experimental-features 'nix-command flakes' run github:nix-community/nixos-anywhere -- \
    --flake github:xxLYNX/nebula#testbed \
    --build-on-remote \
    root@localhost
  ```
  - `--build-on-remote` means the Nix closure is built on the live ISO itself (Nix is already present). This works correctly from Windows operator machines where Nix is unavailable.
  - The live ISO needs internet access to fetch the flake from GitHub.
- After the reboot, SSH into the freshly installed machine with your key.

Post-install first login
- The primary user (`voyager` by default) has `initialPassword = "changeme"`. Change it on first login:
  ```bash
  passwd
  ```
- For production, replace `initialPassword` with a `sops`-encrypted `hashedPassword`.

Terraform (alternative / future use)
- The `terraform/` directory wraps nixos-anywhere in HCL for structured state tracking.
- nixos-anywhere's terraform module executes shell scripts locally, so Terraform must be run from Linux or WSL (not native Windows).
- For native Windows deployments use the direct nixos-anywhere method above.

Key rotation and recovery
- Keep at least two backups of the private key in separate physical locations (e.g., two LUKS-encrypted USBs).
- When you move to a YubiKey or hardware token, generate new recipients and re-encrypt all secrets to include the new recipient; remove the old key recipient after confirming all recoveries.
- To rotate recipients:
  1. Add the new public recipient(s) to the SOPS key list.
  2. Re-encrypt all secrets with the new recipients (SOPS can be used to re-encrypt).
  3. Commit the updated encrypted files.
  4. Remove the old recipient(s) from the metadata after verification.

CI / automation considerations
- Keep a "static" CI job that builds flakes without decrypting secrets — this validates module composition and catches syntax issues.
- Create a protected job (only on protected branches/tags or on manual trigger) that has access to decrypting secrets (make the CI runner a recipient or make it fetch the private key via a secure vault for the duration of the job).
- Never store unencrypted secrets in CI logs or artifacts. Mark outputs as sensitive, and wipe decrypted temp files.

Terraform backend & state note
- For early testing: local state is acceptable for a small single-operator setup.
- For a team or production: use a remote backend with locking (S3+DynamoDB, GCS, or Consul).
- Bootstrapping the backend itself can be done manually (single-time creation) or with a one-off script on a machine that has the secret/access to create backend resources.

Checklist before first push to a new machine
- [ ] Public recipients committed in repo (only public keys).
- [ ] Private key stored only on encrypted USB or hardware token.
- [ ] `inventory/machines.json` entry created for the device with correct hostname, packs/modules, primaryUser, diskDevice.
- [ ] `nixosConfigurations.<host>` available via flake evaluation (`nix build .#nixosConfigurations.<host>.config.system.build.toplevel`) locally.
- [ ] Decrypt test: `sops --decrypt` works when USB is mounted.
- [ ] Local `colmena` or `nixos-rebuild` test run on the device succeeds in a dry run (build).
- [ ] Remove USB after the deployment and check the device functions as expected.

---

Quick contributor guides

## Adding a new machine

1. Add an entry to `inventory/machines.json`:
   ```json
   "myhostname": {
     "hostname": "myhostname",
     "primaryUser": "alice",
     "platform": "linux",
     "role": "testing",
     "packs": ["testing"],
     "tags": ["testing"],
     "swapSize": "8G",
     "diskDevice": "/dev/sda"
   }
   ```
   - `packs` must match flake input names declared in the root `flake.nix` inputs.
2. Create `hosts/myhostname/configuration.nix` (copy from `hosts/testbed/`).
3. Create `hosts/myhostname/hardware-configuration.nix` — nixos-anywhere generates this automatically on first deploy; leave it as `{ ... }: { }` until then.
4. If using a new role, add it to `profiles/roles/<role>/flake.nix` and register it as an input in the root `flake.nix`.
5. Commit and push. Deploy using the nixos-anywhere method above.

## Adding a new NixOS module (system-level)

1. Create `modules/<mymodule>/flake.nix` exporting `nixosModules.default`.
2. Register it as a flake input in the root `flake.nix`:
   ```nix
   mymodule = {
     url = "path:./modules/mymodule";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   ```
3. Add `"mymodule"` to `packs` for any machine in `inventory/machines.json` that should use it.
   The root flake's `mkHost` automatically imports `inputs.mymodule.nixosModules.default` for each pack listed.

## Adding a home-manager module

Home-manager modules live in `modules/desktop/home-modules/` (for desktop-specific fragments) or can be standalone flake modules.

1. Create `modules/desktop/home-modules/<name>/<name>.nix` returning a home-manager module attrset:
   ```nix
   { pkgs, lib ? pkgs.lib }:
   {
     myFragment = { config, pkgs, lib, ... }: {
       options.homeManager.myFeature.enable = lib.mkOption { type = lib.types.bool; default = false; };
       config = lib.mkIf config.homeManager.myFeature.enable {
         home.packages = [ pkgs.mything ];
       };
     };
   }
   ```
2. Import the fragment in the relevant role or host by adding it to `home-manager.users.<user>.imports`:
   ```nix
   home-manager.users.${primaryUser} = {
     imports = [ (import ./modules/desktop/home-modules/myname/myname.nix { inherit pkgs; }).myFragment ];
   };
   ```
3. The desktop module's `homeManagerModules.default` can be used as a standalone home-manager module by importing `desktop.homeManagerModules.default` where `desktop` is the desktop flake input.

## Adding a new role

1. Create `profiles/roles/<role>/flake.nix` exporting `nixosModules.default` as a NixOS module function `{ config, pkgs, primaryUser, machine, ... }: { ... }`.
2. Register it as a flake input in the root `flake.nix` (same as a module above).
3. Set `"role": "<role>"` and add the role name to `"packs"` in `inventory/machines.json` for the target machine.
4. The root flake passes `primaryUser` and `machine` as `_module.args`, so role modules can access per-host data from `machine.diskDevice`, `machine.swapSize`, etc.

Troubleshooting tips
- If `nix build` fails due to missing secrets: ensure `SOPS_AGE_KEY_FILE` is set and the private key is readable by the build process.
- If `colmena` fails while connecting: verify correct SSH host, `ssh_options`, and that the operator machine can reach the device.
- If the device refuses to boot after install: mount the installed system via live environment and inspect `/var/log` and `journalctl` (or rebuild).

Appendix: example minimal commands recap
- Generate keys (operator):
```/dev/null/example-keygen-compact.sh#L1-10
age-keygen -o age_key.txt
grep -v '^#' age_key.txt | head -n1 > secrets/age_recipient.pub
```
- Encrypt a secret:
```/dev/null/sops-encrypt-compact.sh#L1-6
RECIPIENT=$(cat secrets/age_recipient.pub)
sops --encrypt --age "$RECIPIENT" secrets/example.yaml > secrets/example.yaml.enc
```
- Mount USB and decrypt to test:
```/dev/null/usb-decrypt-test-compact.sh#L1-8
sudo cryptsetup luksOpen /dev/sdX secret-usb
sudo mount /dev/mapper/secret-usb /mnt/secret-usb
export SOPS_AGE_KEY_FILE=/mnt/secret-usb/age_key.txt
sops --decrypt secrets/example.yaml.enc > /tmp/example.yaml
# inspect and securely delete /tmp/example.yaml
```
- Apply configuration locally:
```/dev/null/colmena-or-nixos-rebuild-compact.sh#L1-6
# build & switch (local)
sudo nixos-rebuild switch --flake .#nixosConfigurations.<this-host>
# or if using colmena locally (depends on your colmena flake output)
nix build .#colmena.<this-host>
colmena apply -c ./colmena -p <profile>  # adjust per your colmena layout
```

If you want, I will:
- Add `secrets/README.md` with a minimal `sops.yaml` example and a suggested `secrets/` layout.
- Add a small `docs/RECOVERY.md` detailing key rotation and emergency recovery steps.
- Create a minimal GitLab CI job example showing secure vs. protected jobs for static builds and secret-enabled builds.

Which of those follow-ups should I add to the repo next? (secrets README, recovery doc, CI job template)