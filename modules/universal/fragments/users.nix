{
  config,
  lib,
  machine,
  machineEnrolled,
  ...
}:

let
  # From your machines.json
  adminUsers = machine.users.admin or [ ];
  regularUsers = machine.users.regular or [ ];
in
{
  # Passwords come only from secrets once enrolled (best practice with sops-nix)
  users.mutableUsers = !machineEnrolled;

  # Declare the password secret only after enrollment
  sops.secrets = lib.optionalAttrs machineEnrolled {
    user_password_hash = {
      neededForUsers = true;
    };
  };

  # Configure all users from machines.json
  users.users = lib.listToAttrs (
    (map (username: {
      name = username;
      value = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "networkmanager"
        ];
      }
      // (
        if machineEnrolled then
          {
            hashedPasswordFile = config.sops.secrets.user_password_hash.path;
          }
        else
          {
            password = "changeme"; # bootstrap password
          }
      );
    }) adminUsers)
    ++ (map (username: {
      name = username;
      value = {
        isNormalUser = true;
        extraGroups = [ ];
      }
      // (
        if machineEnrolled then
          {
            hashedPasswordFile = config.sops.secrets.user_password_hash.path;
          }
        else
          {
            password = "changeme";
          }
      );
    }) regularUsers)
  );
}
