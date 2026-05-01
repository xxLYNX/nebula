# Secrets directory for the nebula fleet.
#
# Layout:
#   secrets/
#     .sops.yaml           ← key groups and path rules (in repo root, not here)
#     machines/
#       <hostname>/
#         machine.yaml     ← encrypted; sops-nix decrypts to /run/secrets/ at boot
#     management/
#       bootstrap.yaml     ← encrypted; threshold=2 (YubiKey + pluto host key)
#
# Setup checklist (run on each machine after first boot):
#   1. Collect the machine's age public key:
#        nix shell nixpkgs#ssh-to-age --command \
#          sh -c 'ssh-keyscan -t ed25519 <hostname> | ssh-to-age'
#   2. Paste the result into .sops.yaml under the matching anchor (e.g. pluto_host).
#   3. If using YubiKey, run:
#        nix shell nixpkgs#age-plugin-yubikey --command age-plugin-yubikey --generate
#      and paste the recipient into .sops.yaml under yubikey_primary.
#   4. Copy machine.yaml.template → machine.yaml, fill in real values.
#   5. Encrypt: sops --encrypt --in-place secrets/machines/<hostname>/machine.yaml
#   6. Add the sops.secrets.* declaration in the role and switch hashedPasswordFile.
#
# *.yaml files (encrypted) are safe to commit; *.template files are plaintext examples.
# Never commit unencrypted secrets.
