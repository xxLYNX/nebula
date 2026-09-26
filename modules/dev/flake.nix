{
  description = "Development toolchain module (Android SDK, JDK, optional IDE helpers)";

  inputs = {
    nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self, nixpkgs, ... }:
    {
      nixosModules.default =
        { config, pkgs, lib, ... }:
        let
          cfg = config.services.dev or { };
          androidCfg = cfg.android or { };
        in
        {
          options.services.dev = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Install declared dev toolchains on this host (opt-in via inventory).";
            };

            android = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Android SDK (API 35), JDK, platform-tools, and Android Studio with bundled SDK path.";
              };

              jdkPackage = lib.mkOption {
                type = lib.types.package;
                default = pkgs.jdk21;
                description = "JDK on PATH for Gradle; Shotgun targets Java 17 bytecode.";
              };
            };
          };

          config = lib.mkIf cfg.enable (
            lib.mkIf androidCfg.enable (
              let
                androidComposition = pkgs.androidenv.composeAndroidPackages {
                  platformVersions = [ "35" ];
                  buildToolsVersions = [
                    "35.0.0"
                    "34.0.0"
                  ];
                  includeEmulator = false;
                  includeNDK = false;
                  includeSystemImages = false;
                };
                androidSdk = androidComposition.androidsdk;
                platformTools = androidComposition."platform-tools";
                jdk = androidCfg.jdkPackage;
                sdkRoot = "${androidSdk}/libexec/android-sdk";
              in
              {
                nixpkgs.config.android_sdk.accept_license = true;

                environment.systemPackages = [
                  jdk
                  androidSdk
                  platformTools
                  pkgs.android-studio-full
                  (pkgs.writeShellScriptBin "with-android-sdk" ''
                    export JAVA_HOME="${jdk}"
                    export ANDROID_HOME="${sdkRoot}"
                    export ANDROID_SDK_ROOT="$ANDROID_HOME"
                    exec "$@"
                  '')
                ];
              }
            )
          );
        };
    };
}
