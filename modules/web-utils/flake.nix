{
  description = "Web utilities module: zen-browser and browser-related tooling";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Zen browser community flake — provides up-to-date zen-browser binaries.
    # The package is built from GitHub releases, not from source, so the exact
    # nixpkgs pin only affects build tooling, not the browser version.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, zen-browser, ... }: {

    nixosModules.default = { config, pkgs, lib, ... }:
    let
      # Resolve the zen-browser package for this host's system.
      zenPkg = zen-browser.packages.${pkgs.system}.default;
    in {
      options.services.webUtils = {
        enable = lib.mkOption {
          type    = lib.types.bool;
          default = true;
          description = "Master switch for the web-utils module.";
        };

        zenBrowser = {
          enable = lib.mkOption {
            type    = lib.types.bool;
            default = true;
            description = "Install zen-browser for all users.";
          };
          setDefault = lib.mkOption {
            type    = lib.types.bool;
            default = true;
            description = "Set zen-browser as the system default browser via xdg-utils.";
          };
        };
      };

      config = lib.mkIf config.services.webUtils.enable {
        environment.systemPackages =
          lib.optional config.services.webUtils.zenBrowser.enable zenPkg;

        # Register zen-browser as the default browser so xdg-open, MIME handlers,
        # and apps that call $BROWSER all resolve to zen.
        xdg.mime.defaultApplications = lib.mkIf config.services.webUtils.zenBrowser.setDefault {
          "text/html"               = "zen.desktop";
          "x-scheme-handler/http"   = "zen.desktop";
          "x-scheme-handler/https"  = "zen.desktop";
          "x-scheme-handler/ftp"    = "zen.desktop";
          "application/x-extension-htm"   = "zen.desktop";
          "application/x-extension-html"  = "zen.desktop";
          "application/x-extension-xhtml" = "zen.desktop";
        };

        environment.sessionVariables.BROWSER = lib.mkIf config.services.webUtils.zenBrowser.setDefault "zen";
      };
    };

  };
}
