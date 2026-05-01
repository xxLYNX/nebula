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

echo ""
info "Enrollment complete."
info "Next: run 'sudo colmena apply-local --sudo' on $HOSTNAME to activate the new secrets."
info "Then update the role to use 'hashedPasswordFile' instead of 'password = ...'"
