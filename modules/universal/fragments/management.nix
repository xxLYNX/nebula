{
  config,
  lib,
  machineEnrolled,
  ...
}:
{
  # Only declare the secret after enrollment (same pattern we used for the password)
  sops.secrets = lib.optionalAttrs machineEnrolled {
    fleet_ssh_private_key = {
      # Example: make it readable by root only and put it in /etc/ssh/
      path = "/etc/ssh/fleet_ed25519_key";
      owner = "root";
      group = "root";
      mode = "0600";
    };
  };

  # Optional: make the key available as a known host or service key
  # (customize as needed)
}
