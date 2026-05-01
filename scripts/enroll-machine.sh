#!/usr/bin/env bash
# enroll-machine.sh — enroll this machine into the nebula SOPS key pool
#
# What it does:
#   1. Reads /etc/ssh/ssh_host_ed25519_key.pub and converts to an age public key
#   2. Updates .sops.yaml in the repo with this machine's real key (replacing placeholder)
#   3. Prompts for the primary user's password and hashes it with sha-512
#   4. Creates secrets/machines/<hostname>/machine.yaml from the template
#   5. Encrypts the secrets file with sops (recipients come from .sops.yaml)
#   6. Commits .sops.yaml + the encrypted file and pushes to origin
#
# Run as your regular user — no sudo required.
# git push requires your SSH key to be loaded in ssh-agent.
#
# Prerequisites (provided by the universal module after first colmena apply):
#   sops, ssh-to-age, mkpasswd
#
# If running before the first apply (bootstrapping a new machine):
#   nix shell nixpkgs#sops nixpkgs#ssh-to-age nixpkgs#mkpasswd \
#     --command bash scripts/enroll-machine.sh

set -euo pipefail

# ── auto-bootstrap ─────────────────────────────────────────────────────────────
# If sops, ssh-to-age, or mkpasswd aren't in PATH (e.g. first run before the
# universal module has been applied), re-exec the entire script inside a nix shell
# that provides them. Fully transparent — the user doesn't need to do anything.
if ! command -v ssh-to-age >/dev/null 2>&1 \
|| ! command -v sops       >/dev/null 2>&1 \
|| ! command -v mkpasswd   >/dev/null 2>&1; then
  echo "[enroll] Required tools not in PATH — re-execing via nix shell (this downloads once)..."
  exec nix shell nixpkgs#sops nixpkgs#ssh-to-age nixpkgs#mkpasswd \
    --command bash "$0" "$@"
fi

# ── repo root detection ────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$SCRIPT_DIR")"

HOSTNAME="$(hostname -s)"
SOPS_YAML="$REPO/.sops.yaml"
SECRETS_DIR="$REPO/secrets/machines/$HOSTNAME"
TEMPLATE="$SECRETS_DIR/machine.yaml.template"
SECRET_FILE="$SECRETS_DIR/machine.yaml"

# ── helpers ────────────────────────────────────────────────────────────────────
info() { printf '\e[32m[enroll]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[enroll]\e[0m %s\n' "$*"; }
die()  { printf '\e[31m[enroll]\e[0m %s\n' "$*" >&2; exit 1; }

# ── sanity checks ──────────────────────────────────────────────────────────────
[[ -d "$REPO/.git" ]] \
  || die "Cannot find git repo at $REPO. Run this script from within the nebula checkout."

[[ -f "$SOPS_YAML" ]] \
  || die ".sops.yaml not found at $SOPS_YAML"

[[ -f "$TEMPLATE" ]] \
  || die "Template not found: $TEMPLATE
Add secrets/machines/$HOSTNAME/ to the repo before enrolling this machine."

[[ -f "$SECRET_FILE" ]] \
  && die "Encrypted secret already exists: $SECRET_FILE
To re-enroll (e.g. password change), delete it first:
  rm $SECRET_FILE
Then run this script again."

command -v ssh-to-age >/dev/null \
  || die "ssh-to-age not found.
Run: nix shell nixpkgs#sops nixpkgs#ssh-to-age nixpkgs#mkpasswd --command bash $0"

command -v sops >/dev/null \
  || die "sops not found. Same as above."

command -v mkpasswd >/dev/null \
  || die "mkpasswd not found. Same as above."

# ── preflight: verify git remote is reachable before doing any secrets work ───
# git push requires your SSH key to be authorised on the remote (GitHub deploy
# key or personal key in ssh-agent). Check now so we fail fast with a clear
# message rather than hitting auth failure after secrets are already encrypted.
info "Checking git remote access..."
GIT_REMOTE="$(git -C "$REPO" remote get-url origin 2>/dev/null)" \
  || die "No git remote 'origin' configured in $REPO.
Run: git remote add origin <your-repo-url>"

# ls-remote performs a real auth round-trip without writing anything.
if ! git -C "$REPO" ls-remote --exit-code origin HEAD >/dev/null 2>&1; then
  die "Cannot reach git remote: $GIT_REMOTE

The push step requires SSH access to GitHub. Set this up before enrolling:

  Option A — personal key (if your key is on this machine):
    eval \"\$(ssh-agent -s)\"
    ssh-add ~/.ssh/id_ed25519       # or whichever key is authorised on GitHub
    ssh -T git@github.com           # should say 'Hi <user>! You have authenticated'

  Option B — deploy key (recommended for servers):
    ssh-keygen -t ed25519 -f ~/.ssh/nebula_deploy -N ''
    cat ~/.ssh/nebula_deploy.pub    # add this as a read/write deploy key on GitHub
    # Add to ~/.ssh/config:
    #   Host github.com
    #     IdentityFile ~/.ssh/nebula_deploy
    ssh -T git@github.com           # verify, then re-run this script"
fi
info "Git remote reachable — proceeding."

# ── 1. derive age pubkey from ssh host key ─────────────────────────────────────
HOST_PUB="/etc/ssh/ssh_host_ed25519_key.pub"
[[ -f "$HOST_PUB" ]] \
  || die "SSH host key not found at $HOST_PUB.
Generate host keys: sudo ssh-keygen -A"

AGE_PUBKEY="$(ssh-to-age < "$HOST_PUB")"
info "Hostname:        $HOSTNAME"
info "Age public key:  $AGE_PUBKEY"

# ── 2. update .sops.yaml placeholder ──────────────────────────────────────────
PLACEHOLDER="age1AAAA_PLACEHOLDER_run_ssh_to_age_for_${HOSTNAME}"

if grep -qF "$PLACEHOLDER" "$SOPS_YAML"; then
  sed -i "s|${PLACEHOLDER}|${AGE_PUBKEY}|" "$SOPS_YAML"
  info "Updated .sops.yaml with $HOSTNAME key."
elif grep -qF "$AGE_PUBKEY" "$SOPS_YAML"; then
  info ".sops.yaml already contains this key — skipping update."
else
  die "No placeholder for '$HOSTNAME' found in .sops.yaml.
Add the following to the keys block in .sops.yaml, then re-run:

  - &${HOSTNAME}_host age1AAAA_PLACEHOLDER_run_ssh_to_age_for_${HOSTNAME}

Also add *${HOSTNAME}_host to the relevant creation_rules entries."
fi

# ── 3. hash password ───────────────────────────────────────────────────────────
echo ""
info "Enter the password for the primary user on $HOSTNAME:"
read -r -s -p "  Password: " PW;  echo
read -r -s -p "  Confirm:  " PW2; echo

[[ -n "$PW" ]]         || die "Password cannot be empty."
[[ "$PW" == "$PW2" ]] || die "Passwords do not match."

HASHED="$(printf '%s' "$PW" | mkpasswd -m sha-512 -s)"

# Sanity-check the hash — mkpasswd should always produce a string starting with '$'.
# If it doesn't (e.g., wrong flags or old mkpasswd variant), abort before writing.
[[ "$HASHED" == \$* ]] \
  || die "mkpasswd produced unexpected output: '$HASHED'
Expected a crypt hash beginning with '\$'. Check your mkpasswd version."

# ── 4. write plaintext yaml and encrypt ───────────────────────────────────────
# If anything from here to 'trap - ERR' fails, clean up the plaintext file
# immediately so credentials are never left on disk in plaintext.
trap 'rm -f "$SECRET_FILE"
      printf "\e[31m[enroll]\e[0m ERROR: Cleaned up plaintext %s\n" "$SECRET_FILE" >&2' ERR

# Write minimal valid YAML directly rather than substituting into the template
# via sed — sed treats '&' and '\' as metacharacters in the replacement string,
# which could corrupt a hash that contains those characters.
printf 'user_password_hash: "%s"\n' "$HASHED" > "$SECRET_FILE"

info "Encrypting $SECRET_FILE ..."
sops --encrypt --in-place "$SECRET_FILE"
info "Encrypted OK."

# File is now encrypted — disable the plaintext cleanup trap.
trap - ERR

# ── 5. commit and push ─────────────────────────────────────────────────────────
cd "$REPO"

# Ensure git has a committer identity. On a freshly installed machine git
# user.name/email are not set. Set them locally (repo-scope only, not global)
# so the enrollment commit doesn't fail. Use the machine hostname as a
# recognisable identity; the user can run 'git config --global ...' later.
if ! git config user.email >/dev/null 2>&1; then
  warn "git user.email not set — configuring repo-local identity as $HOSTNAME@nebula"
  git config user.email "$HOSTNAME@nebula"
fi
if ! git config user.name >/dev/null 2>&1; then
  git config user.name "$HOSTNAME"
fi

# The encrypted .yaml is gitignored by default to prevent accidental plaintext
# commits. Force-add it here — it's safe to commit once encrypted.
git add "$SOPS_YAML"
git add -f "$SECRET_FILE"

if git diff --cached --quiet; then
  info "Nothing new to commit — $HOSTNAME was already enrolled."
  exit 0
fi

git commit -m "secrets: enroll ${HOSTNAME} into SOPS key pool

Age public key: ${AGE_PUBKEY}

Run 'sudo colmena apply-local --sudo' on ${HOSTNAME} to activate."

info "Pushing to origin..."
git push

# ── 6. apply the new config so sops-nix activates the secret ──────────────────
echo ""
info "Applying new configuration via colmena (this rebuilds NixOS with the SOPS secret)..."
sudo colmena apply-local --sudo

# ── 7. verify SOPS actually worked ────────────────────────────────────────────
echo ""
info "Verifying SOPS decryption..."

SECRET_RUNTIME="/run/secrets/user_password_hash"

# sops-nix writes decrypted secrets to /run/secrets/ at activation.
# If the file is missing, activation failed silently (shouldn't happen with
# neededForUsers = true, but check anyway).
[[ -f "$SECRET_RUNTIME" ]] \
  || die "Verification failed: $SECRET_RUNTIME does not exist.
sops-nix did not decrypt the secret. Check: journalctl -b | grep sops"

RUNTIME_HASH="$(cat "$SECRET_RUNTIME")"

# The runtime hash and the hash we created must match exactly.
[[ "$RUNTIME_HASH" == "$HASHED" ]] \
  || die "Verification failed: runtime hash does not match what was encrypted.
Expected: $HASHED
Got:      $RUNTIME_HASH
The secret file may have been corrupted or the wrong key was used."

# Cross-check: verifies the hash actually authenticates the password the user
# typed by running it through the same kdf and comparing. Uses python3 crypt
# which is available on NixOS without extra packages.
if python3 -c "
import crypt, sys
ok = crypt.crypt('${PW}', '${RUNTIME_HASH}') == '${RUNTIME_HASH}'
sys.exit(0 if ok else 1)
" 2>/dev/null; then
  echo ""
  printf '\e[32m[enroll]\e[0m ✓ Hello SOPS! Password authenticated successfully for %s@%s\n' \
    "$(id -un)" "$HOSTNAME"
  printf '\e[32m[enroll]\e[0m ✓ Secret decrypted to %s\n' "$SECRET_RUNTIME"
  printf '\e[32m[enroll]\e[0m ✓ Hash round-trip verified — login will work\n'
else
  die "Verification failed: the decrypted hash does not authenticate the password you entered.
The hash was written and decrypted correctly, but something went wrong with hashing.
Check: python3 -c \"import crypt; print(crypt.crypt('<password>', open('/run/secrets/user_password_hash').read().strip()))\"
Then compare to: $(cat "$SECRET_RUNTIME")"
fi

echo ""
info "Enrollment complete. $HOSTNAME is fully enrolled in the SOPS key pool."
info "You can now open a new TTY (Ctrl+Alt+F2) and log in with your chosen password."
