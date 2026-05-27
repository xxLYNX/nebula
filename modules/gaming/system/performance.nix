# Gaming performance optimizations for NixOS.
# Provides: CPU frequency scaling, gamemode, microcode updates, kernel tuning.
# Imported by modules/gaming/flake.nix nixosModules.default.

{
  config,
  pkgs,
  lib,
  primaryUser ? null,
  ...
}:

let
  cfg = config.services.gaming or { };
in
lib.mkIf cfg.enable {
  # CPU frequency governor: base governor for system-wide use.
  #
  # Recommended setup for automatic gaming performance + battery savings:
  # - Set cpuGovernor = "schedutil" normally.
  # - Enable GameMode.
  # - Add "gamemoderun %command%" to Steam launch options.
  # - Result: smart scaling normally, performance governor while gaming.
  #
  # Governor options:
  # "schedutil"   = intelligent scaling, good normal-use default.
  # "performance" = always max-performance governor.
  # "powersave"   = low-frequency bias; not recommended as the only gaming mode.
  powerManagement.cpuFreqGovernor = lib.mkDefault cfg.cpuGovernor;

  # CPU microcode updates for Intel/AMD.
  # Improves performance, stability, and security.
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # GameMode: automatically boosts performance when games launch,
  # then reverts when they close.
  #
  # Steam usage:
  #   gamemoderun %command%
  programs.gamemode = lib.mkIf cfg.enableGameMode {
    enable = true;

    # NixOS defaults this to true, but keeping it explicit documents that
    # renice support is expected.
    enableRenice = true;

    settings = {
      general = {
        # GameMode negates this value internally.
        # renice = 10 means the game process gets nice -10.
        # User must be in the "gamemode" group.
        renice = 10;

        # Correct GameMode keys for governor switching.
        # These belong in [general], not [cpu].
        desiredgov = "performance";
        defaultgov = cfg.cpuGovernor;

        # Intel P-State Energy Performance Preference (EPP).
        # Sets CPU energy/performance bias for turbo boost behavior.
        # "performance" = allow max turbo frequencies (required for 4.7GHz on i7-1165G7)
        # Without this, EPP defaults to "balance_performance" which limits turbo.
        desiredepp = "performance";
        defaultepp = "balance_performance";

        # Use firmware/platform performance profile where available.
        desiredprof = "performance";

        # Prevent GameMode from switching to its iGPU-specific governor path.
        # This matters on Intel/iGPU systems, where the example upstream config
        # otherwise uses igpu_desiredgov=powersave under certain load ratios.
        #
        # -1 disables iGPU checking and always uses desiredgov for games.
        igpu_power_threshold = -1;

        # Keep screensaver inhibition enabled while gaming.
        inhibit_screensaver = 1;
      };

      gpu = {
        # Enables GameMode GPU performance hooks where supported.
        # Upstream intentionally requires this exact "accept-responsibility"
        # value for GPU optimizations.
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
      };

      cpu = {
        # [cpu] is for GameMode's parking/pinning features, not governor switching.
        #
        # Leave these off by default unless you have a hybrid CPU or AMD X3D CPU
        # and specifically want to test GameMode's core placement behavior.
        park_cores = "no";
        pin_cores = "no";
      };

      custom = {
        # Custom scripts can be added here if needed.
        # start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
        # end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
      };
    };
  };

  # NixOS's GameMode module creates the "gamemode" group.
  # Add the primary admin user to it when Nebula provides primaryUser.
  users.users = lib.mkIf (cfg.enableGameMode && primaryUser != null) {
    ${primaryUser}.extraGroups = [ "gamemode" ];
  };

  # Performance kernel parameters for gaming.
  # These improve latency and responsiveness during gameplay.
  boot.kernelParams = lib.optionals cfg.enablePerformanceKernelParams [
    # Reduce scheduling latency for better frame timing.
    "preempt=full"

    # Uncomment below for maximum performance at cost of security:
    # Disables CPU vulnerability mitigations (Spectre, Meltdown, etc.)
    # "mitigations=off"
  ];

  # Additional performance monitoring tools.
  environment.systemPackages = with pkgs; [
    gamemode
    libnotify

    # Uncomment if you want these available globally:
    # mangohud
    # cpupower
  ];
}
