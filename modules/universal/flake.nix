{
  description = "Universal module — unconditionally applied to every nebula machine via mkHost. Provides the Nix baseline (flakes, substituters, GC, allowUnfree) and sops-nix host-key wiring. No options; always-on.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs, ... }:
    {
      nixosModules.default =
        { ... }:
        {
          imports = [
            ./fragments/nix-baseline.nix
            ./fragments/sops.nix
            ./fragments/users.nix
          ];
        };
    };
}
