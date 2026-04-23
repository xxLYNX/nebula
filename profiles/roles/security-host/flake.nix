{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, ... }: {
    nixosModules.default = { ... }: {
      #  All security-host stuff (Wazuh, Headscale, AppArmor, etc.) goes here
    };
  };
}
