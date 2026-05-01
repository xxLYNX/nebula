# Fragment: universal Nix baseline settings.
# Applied to every machine in the fleet via the universal module.
# Covers: flakes/nix-command, download resilience, substituters, GC, allowUnfree.
{ pkgs, lib, ... }: {

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features    = [ "nix-command" "flakes" ];
    # Resilience against the interrupted-download store corruption bug (known since 2021):
    # stalled-download-timeout aborts stalled transfers before partial data is committed;
    # connect-timeout prevents hangs on unreachable substituters;
    # download-attempts retries transient failures automatically.
    http-connections         = 50;
    stalled-download-timeout = 90;
    connect-timeout          = 5;
    download-attempts        = 5;
    # Colmena binary cache — trusted at daemon level so no --option trusted-substituters needed.
    substituters             = [ "https://cache.nixos.org" "https://colmena.cachix.org" ];
    trusted-public-keys      = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "colmena.cachix.org-1:7BzpDnjjH8ki2CT3f6GdOk7QAzPOl+1t3LvTLXqYcSg="
    ];
  };

  # Collect old generations weekly. Combined with systemd-boot configurationLimit = 30
  # this keeps both the Nix store and /boot entries bounded without manual intervention.
  nix.gc = {
    automatic = true;
    dates     = "weekly";
    options   = "--delete-older-than 30d";
  };

  # Minimal universally-useful CLI tools. Role and module packages are additive.
  environment.systemPackages = with pkgs; [ git curl ];
}
