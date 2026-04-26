{
  description = "Composable security-host module: AppArmor, lightweight service wiring for Headscale/Wazuh, and safe defaults.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... } @ inputs:
  let
    lib = (import nixpkgs {}).lib;
    pkgs = import nixpkgs { system = "x86_64-linux"; };
  in {
    # Expose a NixOS module fragment under `nixosModules.default`.
    # This module is intentionally lightweight and composable:
    # - it enables kernel-level host hardening (AppArmor)
    # - provides options to wire up headscale / wazuh as systemd units if packages are supplied
    # - does not assume availability of third-party NixOS modules so it is safe to include
    #   in many contexts (dev/staging/prod).
    #
    # Usage (top-level flake should pass `_module.args` with `primaryUser` and `machine`):
    #   imports = [ inputs.modules.security-host.nixosModules.default ];
    #
    # Example configuration in a machine's module composition:
    # services.securityHost.enable = true;
    # services.securityHost.headscale.enable = true;
    # services.securityHost.headscale.package = pkgs.callPackage ./path/to/headscale {};
    #
    nixosModules.default = { config, pkgs, lib, ... }:
      let
        cfg = config.services.securityHost or {};
      in {
        options = {
          services.securityHost = {
            description = "Top-level options for the security-host convenience module";
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable the security-host helpers (AppArmor + optional service wiring).";
            };

            headscale = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "If true and `package` is set, a systemd unit for headscale will be created.";
              };
              package = lib.mkOption {
                type = lib.types.nullOr lib.types.package;
                default = null;
                description = "If set, the provided package will be used as the headscale binary. Leave null to avoid creating a unit.";
              };
            };

            wazuh = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "If true and `package` is set, a systemd unit for the wazuh agent will be created.";
              };
              package = lib.mkOption {
                type = lib.types.nullOr lib.types.package;
                default = null;
                description = "If set, the provided package will be used as the wazuh-agent binary. Leave null to avoid creating a unit.";
              };
            };
          };
        };

        config = lib.mkIf cfg.enable {
          # Kernel-level host hardening
          security.apparmor.enable = true;

          # Recommend enabling a basic firewall by default for hosts classified as security-hosts.
          # This can be overridden at a higher level if you manage firewall rules elsewhere.
          networking.firewall.enable = true;

          # Minimal system packages useful for debugging / recovery. Add more as needed per role.
          environment.systemPackages = with pkgs; [
            vim
            tmux
            htop
          ];

          # Create a systemd unit for headscale only if the user enabled it and provided a package.
          systemd.services.headscale = lib.mkIf (cfg.headscale.enable && cfg.headscale.package != null) {
            description = "Headscale (ZTNA) service — managed as a simple unit from provided package";
            wants = [ "network.target" ];
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              ExecStart = "${cfg.headscale.package}/bin/headscale";
              Restart = "on-failure";
            };
            # Optionally document where to put config: /etc/headscale or use a systemd drop-in
          };

          # Create a systemd unit for Wazuh agent only if enabled and package provided.
          # (We don't assume a specific nixos module; this gives you a safe fallback wiring.)
          systemd.services.wazuh-agent = lib.mkIf (cfg.wazuh.enable && cfg.wazuh.package != null) {
            description = "Wazuh agent (wrapped as a simple systemd unit using provided package)";
            wants = [ "network.target" ];
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              ExecStart = "${cfg.wazuh.package}/bin/wazuh-agent";
              Restart = "on-failure";
            };
          };

          # Helpful small hardening defaults (can be overridden)
          security.sudo.wheelNeedsPassword = true;
        };
      };
  };
}
